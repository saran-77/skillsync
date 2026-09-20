-- SkillSync AI: scoring, gaps, path generation, daily challenge RPCs

create or replace function public.get_assessment_questions(
  p_skill_id uuid default null,
  p_difficulty int default 3,
  p_limit int default 1,
  p_mode text default 'adaptive'
)
returns setof public.questions_public
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select qp.*
  from public.questions_public qp
  join public.questions q on q.id = qp.id
  where q.source = 'curated'
    and q.reviewed = true
    and (p_skill_id is null or q.skill_id = p_skill_id)
    and (
      p_mode = 'interview'
      or q.difficulty = greatest(1, least(5, p_difficulty))
    )
  order by random()
  limit greatest(1, least(p_limit, 20));
end;
$$;

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
  v_is_correct boolean;
  v_correct_count int := 0;
  v_total int := 0;
  v_score numeric;
  v_level text;
  v_skill_scores jsonb := '{}'::jsonb;
  v_skill_totals jsonb := '{}'::jsonb;
  v_sid text;
  v_prof numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_mode not in ('adaptive', 'interview', 'daily', 'practice') then
    raise exception 'Invalid mode';
  end if;

  insert into public.assessments (user_id, mode, time_taken_seconds, topic, completed_at)
  values (v_uid, p_mode, p_time_taken, p_topic, now())
  returning id into v_assessment_id;

  for v_item in select * from jsonb_array_elements(p_answers)
  loop
    v_qid := (v_item->>'question_id')::uuid;
    v_selected := (v_item->>'selected_index')::int;
    v_confidence := coalesce((v_item->>'confidence')::int, 3);

    select correct_index, skill_id, difficulty, stem, explanation
      into v_correct_index, v_skill_id, v_difficulty, v_stem, v_explanation
    from public.questions
    where id = v_qid
      and (
        (p_mode = 'practice')
        or (source = 'curated' and reviewed = true)
      );

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

    v_sid := v_skill_id::text;
    v_skill_totals := jsonb_set(
      v_skill_totals,
      array[v_sid],
      to_jsonb(coalesce((v_skill_totals->>v_sid)::int, 0) + 1)
    );
    if v_is_correct then
      v_skill_scores := jsonb_set(
        v_skill_scores,
        array[v_sid],
        to_jsonb(coalesce((v_skill_scores->>v_sid)::int, 0) + v_difficulty)
      );
    else
      -- Flashcard from miss
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

  -- Update user_skills from per-skill performance
  for v_sid in select jsonb_object_keys(v_skill_totals)
  loop
    v_prof := least(
      10,
      greatest(
        0,
        round(
          (
            coalesce((v_skill_scores->>v_sid)::numeric, 0)
            / nullif((v_skill_totals->>v_sid)::numeric, 0)
          ) * 2,
          2
        )
      )
    );

    insert into public.user_skills (user_id, skill_id, proficiency, updated_at)
    values (v_uid, v_sid::uuid, v_prof, now())
    on conflict (user_id, skill_id) do update
      set proficiency = round((public.user_skills.proficiency * 0.4) + (excluded.proficiency * 0.6), 2),
          updated_at = now();

    insert into public.user_skill_history (user_id, skill_id, proficiency)
    select v_uid, v_sid::uuid, proficiency
    from public.user_skills
    where user_id = v_uid and skill_id = v_sid::uuid;
  end loop;

  -- XP + streak touch
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

create or replace function public.compute_gaps(p_role_id uuid default null)
returns table (
  skill_id uuid,
  skill_name text,
  current_level numeric,
  required_level numeric,
  gap numeric,
  priority text,
  importance int,
  reason text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select coalesce(p_role_id, target_role_id) into v_role
  from public.profiles where id = v_uid;

  if v_role is null then
    raise exception 'No target role set';
  end if;

  return query
  select
    s.id,
    s.name,
    coalesce(us.proficiency, 0)::numeric,
    rs.required_level,
    greatest(round(rs.required_level - coalesce(us.proficiency, 0), 2), 0)::numeric as gap,
    case
      when (rs.required_level - coalesce(us.proficiency, 0)) >= 4 then 'High'
      when (rs.required_level - coalesce(us.proficiency, 0)) >= 2 then 'Medium'
      else 'Low'
    end as priority,
    rs.importance,
    format('Target %s vs current %s', rs.required_level, coalesce(us.proficiency, 0)) as reason
  from public.role_skills rs
  join public.skills s on s.id = rs.skill_id
  left join public.user_skills us on us.skill_id = s.id and us.user_id = v_uid
  where rs.role_id = v_role
  order by (rs.required_level - coalesce(us.proficiency, 0)) * rs.importance desc;
end;
$$;

create or replace function public.generate_learning_path(p_role_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role uuid;
  v_path_id uuid;
  v_why text[] := '{}';
  r record;
  v_order int := 0;
  v_resource uuid;
  v_done uuid[] := '{}';
  v_pending int;
  v_iterations int := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select coalesce(p_role_id, target_role_id) into v_role
  from public.profiles where id = v_uid;

  if v_role is null then
    raise exception 'No target role set';
  end if;

  delete from public.learning_paths where user_id = v_uid and role_id = v_role;

  insert into public.learning_paths (user_id, role_id, why_this_path)
  values (v_uid, v_role, '{}')
  returning id into v_path_id;

  loop
    v_iterations := v_iterations + 1;
    exit when v_iterations > 40;

    select count(*) into v_pending
    from public.role_skills rs
    join public.skills s on s.id = rs.skill_id
    left join public.user_skills us on us.skill_id = s.id and us.user_id = v_uid
    where rs.role_id = v_role
      and greatest(rs.required_level - coalesce(us.proficiency, 0), 0) > 0.5
      and not (s.id = any (v_done));

    exit when v_pending = 0;

    select
      s.id as skill_id,
      s.name,
      greatest(rs.required_level - coalesce(us.proficiency, 0), 0) as gap,
      rs.importance,
      least(5, greatest(1, ceil(rs.required_level / 2.0)::int)) as difficulty
    into r
    from public.role_skills rs
    join public.skills s on s.id = rs.skill_id
    left join public.user_skills us on us.skill_id = s.id and us.user_id = v_uid
    where rs.role_id = v_role
      and greatest(rs.required_level - coalesce(us.proficiency, 0), 0) > 0.5
      and not (s.id = any (v_done))
      and (
        coalesce(cardinality(s.prerequisites), 0) = 0
        or s.prerequisites <@ v_done
        or not exists (
          select 1
          from unnest(s.prerequisites) pr
          join public.role_skills rs2 on rs2.skill_id = pr and rs2.role_id = v_role
          where not (pr = any (v_done))
        )
      )
    order by
      (greatest(rs.required_level - coalesce(us.proficiency, 0), 0) * rs.importance) desc,
      s.name
    limit 1;

    if not found then
      select
        s.id as skill_id,
        s.name,
        greatest(rs.required_level - coalesce(us.proficiency, 0), 0) as gap,
        rs.importance,
        least(5, greatest(1, ceil(rs.required_level / 2.0)::int)) as difficulty
      into r
      from public.role_skills rs
      join public.skills s on s.id = rs.skill_id
      left join public.user_skills us on us.skill_id = s.id and us.user_id = v_uid
      where rs.role_id = v_role
        and greatest(rs.required_level - coalesce(us.proficiency, 0), 0) > 0.5
        and not (s.id = any (v_done))
      order by (greatest(rs.required_level - coalesce(us.proficiency, 0), 0) * rs.importance) desc
      limit 1;
      exit when not found;
    end if;

    v_order := v_order + 1;
    v_done := array_append(v_done, r.skill_id);

    select res.id into v_resource
    from public.resources res
    where res.skill_id = r.skill_id
    order by abs(res.difficulty - r.difficulty)
    limit 1;

    insert into public.path_items (
      path_id, skill_id, resource_id, sort_order, status, estimated_hours, explanation
    ) values (
      v_path_id,
      r.skill_id,
      v_resource,
      v_order,
      case when v_order = 1 then 'in_progress' else 'not_started' end,
      greatest(2, least(8, ceil(r.gap)::int + 2)),
      format('%s closes a gap of %s (importance %s).', r.name, r.gap, r.importance)
    );

    if cardinality(v_why) < 5 then
      v_why := array_append(
        v_why,
        format('%s is next because it closes a gap of %s and unlocks later skills.', r.name, r.gap)
      );
    end if;
  end loop;

  update public.learning_paths set why_this_path = v_why where id = v_path_id;

  return jsonb_build_object(
    'path_id', v_path_id,
    'role_id', v_role,
    'item_count', v_order,
    'why_this_path', to_jsonb(v_why)
  );
end;
$$;

create or replace function public.update_path_item_status(p_item_id uuid, p_status text)
returns public.path_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.path_items;
  v_path_id uuid;
  v_next uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if p_status not in ('not_started', 'in_progress', 'completed') then
    raise exception 'Invalid status';
  end if;

  select pi.* into v_item
  from public.path_items pi
  join public.learning_paths lp on lp.id = pi.path_id
  where pi.id = p_item_id and lp.user_id = v_uid;

  if not found then raise exception 'Not found'; end if;

  update public.path_items set status = p_status where id = p_item_id
  returning * into v_item;

  if p_status = 'completed' then
    update public.profiles
    set xp = xp + 25, updated_at = now()
    where id = v_uid;

    select id into v_next
    from public.path_items
    where path_id = v_item.path_id
      and status = 'not_started'
      and sort_order > v_item.sort_order
    order by sort_order
    limit 1;

    if v_next is not null then
      update public.path_items set status = 'in_progress' where id = v_next;
    end if;
  end if;

  return v_item;
end;
$$;

create or replace function public.complete_daily_challenge(p_answers jsonb, p_time_taken numeric default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
  v_assessment_id uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  if exists (
    select 1 from public.daily_challenges
    where user_id = v_uid and challenge_date = current_date and completed = true
  ) then
    raise exception 'Daily challenge already completed';
  end if;

  v_result := public.submit_assessment('daily', p_answers, p_time_taken, 'daily');
  v_assessment_id := (v_result->>'assessment_id')::uuid;

  insert into public.daily_challenges (user_id, challenge_date, assessment_id, score, completed)
  values (v_uid, current_date, v_assessment_id, (v_result->>'score')::numeric, true)
  on conflict (user_id, challenge_date) do update
    set assessment_id = excluded.assessment_id,
        score = excluded.score,
        completed = true;

  update public.profiles
  set
    xp = xp + 50,
    streak_count = case
      when last_active_date = current_date - 1 then streak_count + 1
      when last_active_date = current_date then streak_count
      else 1
    end,
    last_active_date = current_date,
    updated_at = now()
  where id = v_uid;

  return v_result;
end;
$$;

create or replace function public.review_flashcard(p_card_id uuid, p_quality int)
returns public.flashcards
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_card public.flashcards;
  v_interval int;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  p_quality := greatest(0, least(5, p_quality));

  select * into v_card from public.flashcards where id = p_card_id and user_id = v_uid;
  if not found then raise exception 'Not found'; end if;

  if p_quality < 3 then
    v_interval := 1;
  else
    v_interval := greatest(1, round(v_card.interval_days * v_card.ease)::int);
  end if;

  update public.flashcards
  set
    interval_days = v_interval,
    ease = greatest(1.3, ease + (0.1 - (5 - p_quality) * (0.08 + (5 - p_quality) * 0.02))),
    due_at = now() + make_interval(days => v_interval)
  where id = p_card_id
  returning * into v_card;

  return v_card;
end;
$$;

grant execute on function public.get_assessment_questions(uuid, int, int, text) to authenticated;
grant execute on function public.submit_assessment(text, jsonb, numeric, text) to authenticated;
grant execute on function public.compute_gaps(uuid) to authenticated;
grant execute on function public.generate_learning_path(uuid) to authenticated;
grant execute on function public.update_path_item_status(uuid, text) to authenticated;
grant execute on function public.complete_daily_challenge(jsonb, numeric) to authenticated;
grant execute on function public.review_flashcard(uuid, int) to authenticated;
