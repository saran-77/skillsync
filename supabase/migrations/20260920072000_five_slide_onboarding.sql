-- Five-slide onboarding: profile fields + complete_onboarding RPC

alter table public.questions drop constraint if exists questions_source_check;
alter table public.questions
  add constraint questions_source_check
  check (source in ('curated', 'ai', 'onboarding'));

alter table public.profiles drop constraint if exists profiles_experience_level_check;
alter table public.profiles
  add constraint profiles_experience_level_check
  check (experience_level in ('beginner', 'intermediate', 'advanced', 'pro'));

alter table public.profiles
  add column if not exists learning_goal text not null default '',
  add column if not exists learner_type text
    check (learner_type is null or learner_type in ('student', 'career_switcher', 'working_pro', 'hobbyist')),
  add column if not exists focus_skill_ids uuid[] not null default '{}';

insert into public.model_config (task, model, max_tokens)
values ('onboarding_placement', 'llama-3.1-8b-instant', 2048)
on conflict (task) do nothing;

create or replace function public.complete_onboarding(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_name text;
  v_goal text;
  v_learner text;
  v_role uuid;
  v_level text;
  v_focus uuid[];
  v_answers jsonb;
  v_item jsonb;
  v_qid uuid;
  v_selected int;
  v_correct_index int;
  v_skill_id uuid;
  v_difficulty int;
  v_concept text;
  v_is_correct boolean;
  v_correct int := 0;
  v_total int := 0;
  v_score numeric;
  v_base numeric;
  v_prof numeric;
  v_skill uuid;
  v_path jsonb;
  v_skill_correct int;
  v_skill_total int;
  v_rec text;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  v_name := trim(coalesce(p_payload->>'full_name', ''));
  v_goal := trim(coalesce(p_payload->>'learning_goal', ''));
  v_learner := p_payload->>'learner_type';
  v_role := (p_payload->>'target_role_id')::uuid;
  v_level := p_payload->>'experience_level';
  v_answers := coalesce(p_payload->'answers', '[]'::jsonb);

  if v_name = '' then raise exception 'Name is required'; end if;
  if v_learner is null or v_learner not in ('student', 'career_switcher', 'working_pro', 'hobbyist') then
    raise exception 'Invalid learner type';
  end if;
  if v_role is null then raise exception 'Target role is required'; end if;
  if v_level is null or v_level not in ('beginner', 'intermediate', 'advanced', 'pro') then
    raise exception 'Invalid experience level';
  end if;
  if jsonb_typeof(v_answers) <> 'array' or jsonb_array_length(v_answers) < 3 then
    raise exception 'Complete the placement quiz first';
  end if;

  select coalesce(
    array_agg(x::uuid),
    '{}'
  ) into v_focus
  from jsonb_array_elements_text(coalesce(p_payload->'focus_skill_ids', '[]'::jsonb)) as t(x);

  if cardinality(v_focus) = 0 then
    select coalesce(array_agg(rs.skill_id), '{}')
    into v_focus
    from public.role_skills rs
    where rs.role_id = v_role;
  end if;

  -- Score quiz server-side
  for v_item in select * from jsonb_array_elements(v_answers)
  loop
    v_qid := (v_item->>'question_id')::uuid;
    v_selected := (v_item->>'selected_index')::int;

    select correct_index, skill_id, difficulty, concept
      into v_correct_index, v_skill_id, v_difficulty, v_concept
    from public.questions
    where id = v_qid
      and source in ('onboarding', 'curated', 'ai')
      and reviewed = true;

    if not found then continue; end if;

    v_is_correct := (v_selected = v_correct_index);
    v_total := v_total + 1;
    if v_is_correct then v_correct := v_correct + 1; end if;

    perform public.record_skill_event(
      v_uid, v_skill_id, 'assessment', v_qid, v_is_correct,
      case when v_is_correct then 100 else 0 end,
      v_difficulty, null, coalesce((v_item->>'confidence')::int, 3), v_concept,
      jsonb_build_object('onboarding', true)
    );
  end loop;

  if v_total = 0 then raise exception 'No valid quiz answers'; end if;
  v_score := round((v_correct::numeric / v_total::numeric) * 100, 2);

  v_base := case v_level
    when 'beginner' then 1.5
    when 'intermediate' then 2.5
    when 'advanced' then 3.5
    when 'pro' then 4.5
    else 2.0
  end;

  -- Seed focus skills from level + overall accuracy (and per-skill when possible)
  foreach v_skill in array v_focus
  loop
    select
      count(*) filter (where (a->>'question_id')::uuid in (
        select id from public.questions q where q.skill_id = v_skill
      ) and (
        select correct_index from public.questions q2 where q2.id = (a->>'question_id')::uuid
      ) = (a->>'selected_index')::int),
      count(*) filter (where (a->>'question_id')::uuid in (
        select id from public.questions q where q.skill_id = v_skill
      ))
    into v_skill_correct, v_skill_total
    from jsonb_array_elements(v_answers) a;

    if coalesce(v_skill_total, 0) > 0 then
      v_prof := least(10, greatest(0.5,
        v_base + ((v_skill_correct::numeric / v_skill_total::numeric) - 0.5) * 3
      ));
    else
      v_prof := least(10, greatest(0.5,
        v_base + ((v_score / 100.0) - 0.5) * 2
      ));
    end if;

    insert into public.user_skills (user_id, skill_id, proficiency, updated_at)
    values (v_uid, v_skill, round(v_prof, 2), now())
    on conflict (user_id, skill_id) do update
      set proficiency = excluded.proficiency,
          updated_at = now();

    insert into public.user_skill_history (user_id, skill_id, proficiency)
    values (v_uid, v_skill, round(v_prof, 2));

    perform public.recompute_skill_mastery(v_uid, v_skill);
  end loop;

  update public.profiles set
    full_name = v_name,
    learning_goal = v_goal,
    learner_type = v_learner,
    target_role_id = v_role,
    experience_level = v_level,
    focus_skill_ids = v_focus,
    onboarding_complete = true,
    xp = xp + 25,
    updated_at = now()
  where id = v_uid;

  v_path := public.generate_learning_path(v_role);

  v_rec := case
    when v_score >= 80 then 'Strong placement — your path emphasizes remaining gaps at a higher bar.'
    when v_score >= 50 then 'Solid start — we mixed fundamentals with stretch modules for your focus skills.'
    else 'We will start with foundations for your focus skills and unlock advanced modules as you pass quizzes.'
  end;

  return jsonb_build_object(
    'score', v_score,
    'correct', v_correct,
    'total', v_total,
    'path_id', v_path->>'path_id',
    'item_count', v_path->>'item_count',
    'recommendation', v_rec,
    'experience_level', v_level,
    'learner_type', v_learner
  );
end;
$$;

grant execute on function public.complete_onboarding(jsonb) to authenticated;
