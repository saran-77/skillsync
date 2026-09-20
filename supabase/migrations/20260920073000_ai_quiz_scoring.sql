-- Allow scoring reviewed AI / onboarding questions on all quiz surfaces

insert into public.model_config (task, model, max_tokens)
values ('quiz_batch', 'llama-3.3-70b-versatile', 4096)
on conflict (task) do update
  set model = excluded.model,
      max_tokens = excluded.max_tokens,
      updated_at = now();

create or replace function public.submit_assessment(
  p_mode text,
  p_answers jsonb,
  p_time_taken numeric default 0,
  p_topic text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_assessment_id uuid;
  v_item jsonb;
  v_qid uuid;
  v_selected int;
  v_confidence int;
  v_correct_index int;
  v_skill_id uuid;
  v_difficulty int;
  v_stem text;
  v_explanation text;
  v_concept text;
  v_is_correct boolean;
  v_correct_count int := 0;
  v_total int := 0;
  v_score numeric;
  v_level text;
  v_event_type text;
  v_per_q_time numeric;
  v_skills uuid[] := '{}';
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_mode not in ('adaptive', 'interview', 'daily', 'practice') then
    raise exception 'Invalid mode';
  end if;

  v_event_type := case p_mode
    when 'practice' then 'practice'
    when 'daily' then 'daily'
    when 'interview' then 'interview'
    else 'assessment'
  end;

  insert into public.assessments (user_id, mode, time_taken_seconds, topic, completed_at)
  values (v_uid, p_mode, p_time_taken, p_topic, now())
  returning id into v_assessment_id;

  v_per_q_time := case
    when jsonb_array_length(p_answers) > 0 then p_time_taken / jsonb_array_length(p_answers)
    else p_time_taken
  end;

  for v_item in select * from jsonb_array_elements(p_answers)
  loop
    v_qid := (v_item->>'question_id')::uuid;
    v_selected := (v_item->>'selected_index')::int;
    v_confidence := coalesce((v_item->>'confidence')::int, 3);

    select correct_index, skill_id, difficulty, stem, explanation, concept
      into v_correct_index, v_skill_id, v_difficulty, v_stem, v_explanation, v_concept
    from public.questions
    where id = v_qid
      and reviewed = true
      and source in ('curated', 'ai', 'onboarding');

    if not found then
      continue;
    end if;

    v_is_correct := (v_selected = v_correct_index);
    v_total := v_total + 1;
    if v_is_correct then
      v_correct_count := v_correct_count + 1;
    end if;

    insert into public.assessment_answers (assessment_id, question_id, selected_index, is_correct, confidence)
    values (v_assessment_id, v_qid, v_selected, v_is_correct, v_confidence);

    perform public.record_skill_event(
      v_uid,
      v_skill_id,
      v_event_type,
      v_qid,
      v_is_correct,
      case when v_is_correct then 100 else 0 end,
      v_difficulty,
      v_per_q_time,
      v_confidence,
      v_concept,
      jsonb_build_object('assessment_id', v_assessment_id, 'mode', p_mode)
    );

    if not (v_skill_id = any (v_skills)) then
      v_skills := array_append(v_skills, v_skill_id);
    end if;

    if not v_is_correct then
      insert into public.flashcards (user_id, question_id, skill_id, front, back, due_at, interval_days)
      values (
        v_uid,
        v_qid,
        v_skill_id,
        v_stem,
        coalesce(nullif(v_explanation, ''), 'Review this concept carefully.'),
        now() + interval '1 day',
        1
      );
    end if;
  end loop;

  if v_total = 0 then
    raise exception 'No valid answers';
  end if;

  v_score := round((v_correct_count::numeric / v_total::numeric) * 10, 2);
  if v_score <= 3 then
    v_level := 'Beginner';
  elsif v_score <= 7 then
    v_level := 'Intermediate';
  else
    v_level := 'Advanced';
  end if;

  update public.assessments
  set score = v_score, level = v_level
  where id = v_assessment_id;

  insert into public.user_skill_history (user_id, skill_id, proficiency)
  select v_uid, sm.skill_id, round(sm.mastery_score / 10.0, 2)
  from public.skill_mastery sm
  where sm.user_id = v_uid and sm.skill_id = any (v_skills);

  update public.profiles
  set
    xp = xp + (v_correct_count * 10),
    last_active_date = current_date,
    streak_count = case
      when last_active_date = current_date then streak_count
      when last_active_date = current_date - 1 then streak_count + 1
      else 1
    end,
    updated_at = now()
  where id = v_uid;

  return jsonb_build_object(
    'assessment_id', v_assessment_id,
    'score', v_score,
    'level', v_level,
    'correct', v_correct_count,
    'total', v_total,
    'recommendation', case
      when v_score <= 3 then 'Focus on fundamentals for your target role.'
      when v_score <= 7 then 'Solid progress — close medium gaps next.'
      else 'Strong showing — push advanced path items.'
    end
  );
end;
$$;

-- Patch module quiz scoring to accept AI questions for the module skill
create or replace function public.submit_module_quiz(p_item_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.path_items;
  v_item_ans jsonb;
  v_qid uuid;
  v_selected int;
  v_correct_index int;
  v_skill_id uuid;
  v_difficulty int;
  v_stem text;
  v_explanation text;
  v_concept text;
  v_is_correct boolean;
  v_correct int := 0;
  v_total int := 0;
  v_score numeric;
  v_passed boolean;
  v_attempt_id uuid;
  v_misses jsonb := '[]'::jsonb;
  v_next uuid := null;
  v_detail jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select pi.* into v_item
  from public.path_items pi
  join public.learning_paths lp on lp.id = pi.path_id
  where pi.id = p_item_id and lp.user_id = v_uid;
  if not found then raise exception 'Not found'; end if;
  if v_item.status = 'completed' then
    raise exception 'Module already completed';
  end if;
  if not public._path_item_unlocked(v_item) then
    raise exception 'Module is locked';
  end if;

  for v_item_ans in select * from jsonb_array_elements(p_answers)
  loop
    v_qid := (v_item_ans->>'question_id')::uuid;
    v_selected := (v_item_ans->>'selected_index')::int;

    select correct_index, skill_id, difficulty, stem, explanation, concept
      into v_correct_index, v_skill_id, v_difficulty, v_stem, v_explanation, v_concept
    from public.questions
    where id = v_qid
      and skill_id = v_item.skill_id
      and reviewed = true
      and source in ('curated', 'ai', 'onboarding');

    if not found then continue; end if;

    v_is_correct := (v_selected = v_correct_index);
    v_total := v_total + 1;
    if v_is_correct then v_correct := v_correct + 1; end if;

    perform public.record_skill_event(
      v_uid, v_skill_id, 'module', v_qid, v_is_correct,
      case when v_is_correct then 100 else 0 end,
      v_difficulty, null, coalesce((v_item_ans->>'confidence')::int, 3), v_concept,
      jsonb_build_object('path_item_id', p_item_id)
    );

    v_detail := v_detail || jsonb_build_array(jsonb_build_object(
      'question_id', v_qid,
      'selected_index', v_selected,
      'correct_index', v_correct_index,
      'is_correct', v_is_correct,
      'explanation', v_explanation,
      'stem', v_stem,
      'concept', v_concept
    ));

    if not v_is_correct then
      v_misses := v_misses || jsonb_build_array(jsonb_build_object(
        'question_id', v_qid,
        'stem', v_stem,
        'explanation', v_explanation,
        'concept', v_concept,
        'correct_index', v_correct_index,
        'selected_index', v_selected
      ));
      insert into public.flashcards (user_id, question_id, skill_id, front, back, due_at, interval_days)
      values (
        v_uid, v_qid, v_skill_id, v_stem,
        coalesce(nullif(v_explanation, ''), 'Review this module concept.'),
        now() + interval '1 day', 1
      );
    end if;
  end loop;

  if v_total = 0 then raise exception 'No valid answers'; end if;

  v_score := round((v_correct::numeric / v_total::numeric) * 100, 2);
  v_passed := v_score >= 70;

  insert into public.module_attempts (user_id, path_item_id, score, correct, total, passed, answers)
  values (v_uid, p_item_id, v_score, v_correct, v_total, v_passed, v_detail)
  returning id into v_attempt_id;

  update public.path_items
  set
    attempts = attempts + 1,
    best_score = greatest(coalesce(best_score, 0), v_score),
    status = case when v_passed then 'completed' else 'in_progress' end,
    passed_at = case when v_passed then now() else passed_at end
  where id = p_item_id
  returning * into v_item;

  if v_passed then
    update public.profiles set xp = xp + 40, updated_at = now() where id = v_uid;

    select id into v_next
    from public.path_items
    where path_id = v_item.path_id
      and sort_order > v_item.sort_order
      and status = 'locked'
    order by sort_order
    limit 1;

    if v_next is not null then
      update public.path_items set status = 'not_started' where id = v_next;
    end if;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'score', v_score,
    'correct', v_correct,
    'total', v_total,
    'passed', v_passed,
    'pass_percent', 70,
    'misses', v_misses,
    'next_item_id', v_next,
    'path_item', to_jsonb(v_item)
  );
end;
$$;

grant execute on function public.submit_assessment(text, jsonb, numeric, text) to authenticated;
grant execute on function public.submit_module_quiz(uuid, jsonb) to authenticated;
