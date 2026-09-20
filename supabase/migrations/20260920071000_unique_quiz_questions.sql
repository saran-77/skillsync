-- Non-repeating questions: exclude session IDs + recent history when pool allows

drop function if exists public.get_assessment_questions(uuid, int, int, text);

create or replace function public.get_assessment_questions(
  p_skill_id uuid default null,
  p_difficulty int default 3,
  p_limit int default 1,
  p_mode text default 'adaptive',
  p_exclude uuid[] default '{}'
)
returns setof public.questions_public
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := greatest(1, least(coalesce(p_limit, 1), 20));
  v_exclude uuid[] := coalesce(p_exclude, '{}');
  v_recent uuid[] := '{}';
  v_available int;
begin
  if v_uid is not null then
    select coalesce(array_agg(distinct se.question_id), '{}')
    into v_recent
    from public.skill_events se
    where se.user_id = v_uid
      and se.question_id is not null
      and se.created_at > now() - interval '14 days';
  end if;

  -- Prefer pool excluding session + recent history
  select count(*) into v_available
  from public.questions q
  where q.source = 'curated'
    and q.reviewed = true
    and (p_skill_id is null or q.skill_id = p_skill_id)
    and (
      p_mode = 'interview'
      or q.difficulty = greatest(1, least(5, coalesce(p_difficulty, 3)))
    )
    and not (q.id = any (v_exclude))
    and not (q.id = any (v_recent));

  if v_available >= v_limit then
    return query
    select qp.*
    from public.questions_public qp
    join public.questions q on q.id = qp.id
    where q.source = 'curated'
      and q.reviewed = true
      and (p_skill_id is null or q.skill_id = p_skill_id)
      and (
        p_mode = 'interview'
        or q.difficulty = greatest(1, least(5, coalesce(p_difficulty, 3)))
      )
      and not (q.id = any (v_exclude))
      and not (q.id = any (v_recent))
    order by random()
    limit v_limit;
    return;
  end if;

  -- Fallback: honor in-session excludes only (recycle history when bank exhausted)
  return query
  select qp.*
  from public.questions_public qp
  join public.questions q on q.id = qp.id
  where q.source = 'curated'
    and q.reviewed = true
    and (p_skill_id is null or q.skill_id = p_skill_id)
    and (
      p_mode = 'interview'
      or q.difficulty = greatest(1, least(5, coalesce(p_difficulty, 3)))
    )
    and not (q.id = any (v_exclude))
  order by random()
  limit v_limit;
end;
$$;

create or replace function public.get_module_quiz(p_item_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.path_items;
  v_skill_name text;
  v_questions jsonb;
  v_seen uuid[] := '{}';
  v_need int := 5;
  v_unseen_count int;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select pi.* into v_item
  from public.path_items pi
  join public.learning_paths lp on lp.id = pi.path_id
  where pi.id = p_item_id and lp.user_id = v_uid;
  if not found then raise exception 'Not found'; end if;
  if not public._path_item_unlocked(v_item) then
    raise exception 'Module is locked';
  end if;

  select name into v_skill_name from public.skills where id = v_item.skill_id;

  -- Question IDs already attempted on this module
  select coalesce(array_agg(distinct (elem->>'question_id')::uuid), '{}')
  into v_seen
  from public.module_attempts ma
  cross join lateral jsonb_array_elements(ma.answers) elem
  where ma.user_id = v_uid
    and ma.path_item_id = p_item_id
    and elem ? 'question_id';

  select count(*) into v_unseen_count
  from public.questions q
  where q.skill_id = v_item.skill_id
    and q.source = 'curated'
    and q.reviewed = true
    and not (q.id = any (v_seen));

  if v_unseen_count >= least(v_need, 3) then
    select coalesce(jsonb_agg(to_jsonb(q) order by q.prefer desc, q.rnd), '[]'::jsonb)
    into v_questions
    from (
      select
        qp.id, qp.skill_id, qp.difficulty, qp.stem, qp.options, qp.explanation, qp.concept,
        case when qp.stem ilike 'Scenario:%' then 1 else 0 end as prefer,
        random() as rnd
      from public.questions_public qp
      join public.questions raw on raw.id = qp.id
      where qp.skill_id = v_item.skill_id
        and raw.source = 'curated'
        and raw.reviewed = true
        and not (qp.id = any (v_seen))
      order by prefer desc, rnd
      limit v_need
    ) q;
  else
    -- Bank exhausted for this module: unique within this quiz only
    select coalesce(jsonb_agg(to_jsonb(q) order by q.prefer desc, q.rnd), '[]'::jsonb)
    into v_questions
    from (
      select
        qp.id, qp.skill_id, qp.difficulty, qp.stem, qp.options, qp.explanation, qp.concept,
        case when qp.stem ilike 'Scenario:%' then 1 else 0 end as prefer,
        random() as rnd
      from public.questions_public qp
      join public.questions raw on raw.id = qp.id
      where qp.skill_id = v_item.skill_id
        and raw.source = 'curated'
        and raw.reviewed = true
      order by prefer desc, rnd
      limit v_need
    ) q;
  end if;

  if v_questions is null or jsonb_array_length(v_questions) < 3 then
    raise exception 'Not enough questions for this module yet';
  end if;

  return jsonb_build_object(
    'path_item_id', v_item.id,
    'skill_id', v_item.skill_id,
    'skill_name', v_skill_name,
    'pass_percent', 70,
    'questions', v_questions
  );
end;
$$;

grant execute on function public.get_assessment_questions(uuid, int, int, text, uuid[]) to authenticated;
grant execute on function public.get_module_quiz(uuid) to authenticated;
