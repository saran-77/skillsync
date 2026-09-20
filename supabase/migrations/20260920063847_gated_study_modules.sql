-- Gated study modules: lessons, attempts, locked progression

-- path_items: locked status + quiz stats
alter table public.path_items drop constraint if exists path_items_status_check;
alter table public.path_items
  add constraint path_items_status_check
  check (status in ('locked', 'not_started', 'in_progress', 'completed'));

alter table public.path_items
  add column if not exists best_score numeric(6,2),
  add column if not exists attempts int not null default 0,
  add column if not exists passed_at timestamptz;

-- Existing paths: lock everything after the first incomplete module
update public.path_items pi
set status = 'locked'
where pi.status in ('not_started', 'in_progress')
  and pi.sort_order > coalesce((
    select min(p2.sort_order)
    from public.path_items p2
    where p2.path_id = pi.path_id
      and p2.status <> 'completed'
  ), pi.sort_order);

update public.path_items pi
set status = 'not_started'
where pi.status = 'in_progress'
  and exists (
    select 1 from public.path_items p2
    where p2.path_id = pi.path_id
      and p2.sort_order < pi.sort_order
      and p2.status <> 'completed'
  );

-- skill_events: allow module
alter table public.skill_events drop constraint if exists skill_events_event_type_check;
alter table public.skill_events
  add constraint skill_events_event_type_check
  check (event_type in (
    'assessment', 'practice', 'daily', 'interview', 'flashcard', 'challenge', 'module'
  ));

create table if not exists public.skill_lessons (
  id uuid primary key default gen_random_uuid(),
  skill_id uuid not null references public.skills(id) on delete cascade,
  sort_order int not null default 1,
  title text not null,
  body_md text not null,
  estimated_minutes int not null default 5,
  created_at timestamptz not null default now()
);

create index if not exists idx_skill_lessons_skill on public.skill_lessons(skill_id, sort_order);

create table if not exists public.module_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  path_item_id uuid not null references public.path_items(id) on delete cascade,
  score numeric(6,2) not null,
  correct int not null,
  total int not null,
  passed boolean not null default false,
  answers jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_module_attempts_user on public.module_attempts(user_id, created_at desc);
create index if not exists idx_module_attempts_item on public.module_attempts(path_item_id, created_at desc);

alter table public.skill_lessons enable row level security;
alter table public.module_attempts enable row level security;

drop policy if exists skill_lessons_select on public.skill_lessons;
create policy skill_lessons_select on public.skill_lessons for select to authenticated using (true);

drop policy if exists module_attempts_select on public.module_attempts;
create policy module_attempts_select on public.module_attempts for select to authenticated
  using (user_id = auth.uid());

-- Seed lessons (1–2 per skill)
insert into public.skill_lessons (skill_id, sort_order, title, body_md, estimated_minutes)
select s.id, 1, 'Core ideas', format(
  E'## %s\n\n**What you will learn**\n- Core vocabulary and mental models\n- How this skill shows up in real tasks\n- Common pitfalls beginners hit\n\n**Key ideas**\n1. Start from definitions, then apply them to a small example.\n2. Prefer clear structure over memorizing edge cases.\n3. Check your work with a tiny scenario before harder problems.\n\n**Common pitfalls**\n- Rushing without reading the full problem\n- Confusing related concepts that share similar names\n- Skipping prerequisites that this skill depends on\n\nWhen you feel ready, take the module quiz (70%% to unlock the next module).',
  s.name
), 6
from public.skills s
where not exists (select 1 from public.skill_lessons sl where sl.skill_id = s.id and sl.sort_order = 1);

insert into public.skill_lessons (skill_id, sort_order, title, body_md, estimated_minutes)
select s.id, 2, 'Practice mindset', format(
  E'## Applying %s\n\n**Scenario framing**\nTreat each quiz item like a workplace ticket: identify the goal, constraints, and the safest correct action.\n\n**Study checklist**\n- [ ] Skim external docs/resources linked in this module\n- [ ] Rewrite one concept in your own words\n- [ ] Predict one mistake you might make, then avoid it\n\n**Pass rule**\nScore at least **70%%** on the scenario quiz to unlock the next module. Misses become flashcards and update your Skill DNA.',
  s.name
), 4
from public.skills s
where not exists (select 1 from public.skill_lessons sl where sl.skill_id = s.id and sl.sort_order = 2);

-- Helper: is module unlocked for user
create or replace function public._path_item_unlocked(p_item public.path_items)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_prev_incomplete int;
begin
  if p_item.status = 'completed' then
    return true;
  end if;
  select count(*) into v_prev_incomplete
  from public.path_items pi
  where pi.path_id = p_item.path_id
    and pi.sort_order < p_item.sort_order
    and pi.status <> 'completed';
  return v_prev_incomplete = 0;
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
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select coalesce(p_role_id, target_role_id) into v_role
  from public.profiles where id = v_uid;
  if v_role is null then raise exception 'No target role set'; end if;

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
      s.id as skill_id, s.name,
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
          select 1 from unnest(s.prerequisites) pr
          join public.role_skills rs2 on rs2.skill_id = pr and rs2.role_id = v_role
          where not (pr = any (v_done))
        )
      )
    order by (greatest(rs.required_level - coalesce(us.proficiency, 0), 0) * rs.importance) desc, s.name
    limit 1;

    if not found then
      select s.id as skill_id, s.name,
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
      path_id, skill_id, resource_id, sort_order, status, estimated_hours, explanation,
      best_score, attempts, passed_at
    ) values (
      v_path_id, r.skill_id, v_resource, v_order,
      case when v_order = 1 then 'not_started' else 'locked' end,
      greatest(2, least(8, ceil(r.gap)::int + 2)),
      format('%s closes a gap of %s (importance %s). Pass the module quiz (70%%) to unlock the next step.', r.name, r.gap, r.importance),
      null, 0, null
    );

    if cardinality(v_why) < 5 then
      v_why := array_append(v_why, format('%s is gated: study, then pass scenarios to continue.', r.name));
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
begin
  -- Completion only via submit_module_quiz
  if p_status = 'completed' then
    raise exception 'Complete modules by passing the quiz';
  end if;
  if p_status not in ('not_started', 'in_progress') then
    raise exception 'Invalid status';
  end if;
  return public.start_path_module(p_item_id);
end;
$$;

create or replace function public.start_path_module(p_item_id uuid)
returns public.path_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.path_items;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select pi.* into v_item
  from public.path_items pi
  join public.learning_paths lp on lp.id = pi.path_id
  where pi.id = p_item_id and lp.user_id = v_uid;

  if not found then raise exception 'Not found'; end if;
  if v_item.status = 'completed' then return v_item; end if;
  if not public._path_item_unlocked(v_item) then
    raise exception 'Module is locked. Pass the previous module first.';
  end if;

  update public.path_items
  set status = 'in_progress'
  where id = p_item_id
  returning * into v_item;

  return v_item;
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
    limit 5
  ) q;

  if jsonb_array_length(v_questions) < 3 then
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
    where id = v_qid and skill_id = v_item.skill_id and source = 'curated' and reviewed = true;

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

create or replace function public.get_module_progress()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role uuid;
  v_path_id uuid;
  v_total int := 0;
  v_done int := 0;
  v_current jsonb;
  v_recent jsonb;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  select target_role_id into v_role from public.profiles where id = v_uid;

  select id into v_path_id
  from public.learning_paths
  where user_id = v_uid and (v_role is null or role_id = v_role)
  order by created_at desc
  limit 1;

  if v_path_id is null then
    return jsonb_build_object(
      'has_path', false,
      'completed', 0,
      'total', 0,
      'current', null,
      'recent_misses', '[]'::jsonb
    );
  end if;

  select count(*), count(*) filter (where status = 'completed')
  into v_total, v_done
  from public.path_items where path_id = v_path_id;

  select to_jsonb(x) into v_current
  from (
    select pi.id, pi.status, pi.sort_order, pi.best_score, pi.attempts, s.name as skill_name, s.id as skill_id
    from public.path_items pi
    join public.skills s on s.id = pi.skill_id
    where pi.path_id = v_path_id
      and pi.status in ('not_started', 'in_progress')
    order by pi.sort_order
    limit 1
  ) x;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.created_at desc), '[]'::jsonb)
  into v_recent
  from (
    select
      ma.id, ma.score, ma.passed, ma.created_at, ma.path_item_id,
      s.name as skill_name,
      (
        select coalesce(jsonb_agg(elem), '[]'::jsonb)
        from jsonb_array_elements(ma.answers) elem
        where (elem->>'is_correct')::boolean is false
      ) as misses
    from public.module_attempts ma
    join public.path_items pi on pi.id = ma.path_item_id
    join public.skills s on s.id = pi.skill_id
    where ma.user_id = v_uid and pi.path_id = v_path_id
    order by ma.created_at desc
    limit 5
  ) m;

  return jsonb_build_object(
    'has_path', true,
    'path_id', v_path_id,
    'completed', v_done,
    'total', v_total,
    'current', v_current,
    'recent_attempts', v_recent
  );
end;
$$;

grant execute on function public.start_path_module(uuid) to authenticated;
grant execute on function public.get_module_quiz(uuid) to authenticated;
grant execute on function public.submit_module_quiz(uuid, jsonb) to authenticated;
grant execute on function public.get_module_progress() to authenticated;
grant execute on function public.generate_learning_path(uuid) to authenticated;
grant execute on function public.update_path_item_status(uuid, text) to authenticated;
