-- Preserve path progress: generate merges; reset wipes intentionally

-- Shared: ordered gap skills for a user+role (topo / importance)
create or replace function public._path_gap_skills(p_uid uuid, p_role uuid)
returns table (
  skill_id uuid,
  skill_name text,
  gap numeric,
  importance numeric,
  difficulty int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_done uuid[] := '{}';
  v_pending int;
  v_iterations int := 0;
  r record;
begin
  loop
    v_iterations := v_iterations + 1;
    exit when v_iterations > 40;

    select count(*) into v_pending
    from public.role_skills rs
    join public.skills s on s.id = rs.skill_id
    left join public.user_skills us on us.skill_id = s.id and us.user_id = p_uid
    where rs.role_id = p_role
      and greatest(rs.required_level - coalesce(us.proficiency, 0), 0) > 0.5
      and not (s.id = any (v_done));
    exit when v_pending = 0;

    select
      s.id as sid, s.name as sname,
      greatest(rs.required_level - coalesce(us.proficiency, 0), 0) as sgap,
      rs.importance as simp,
      least(5, greatest(1, ceil(rs.required_level / 2.0)::int)) as sdiff
    into r
    from public.role_skills rs
    join public.skills s on s.id = rs.skill_id
    left join public.user_skills us on us.skill_id = s.id and us.user_id = p_uid
    where rs.role_id = p_role
      and greatest(rs.required_level - coalesce(us.proficiency, 0), 0) > 0.5
      and not (s.id = any (v_done))
      and (
        coalesce(cardinality(s.prerequisites), 0) = 0
        or s.prerequisites <@ v_done
        or not exists (
          select 1 from unnest(s.prerequisites) pr
          join public.role_skills rs2 on rs2.skill_id = pr and rs2.role_id = p_role
          where not (pr = any (v_done))
        )
      )
    order by (greatest(rs.required_level - coalesce(us.proficiency, 0), 0) * rs.importance) desc, s.name
    limit 1;

    if not found then
      select
        s.id as sid, s.name as sname,
        greatest(rs.required_level - coalesce(us.proficiency, 0), 0) as sgap,
        rs.importance as simp,
        least(5, greatest(1, ceil(rs.required_level / 2.0)::int)) as sdiff
      into r
      from public.role_skills rs
      join public.skills s on s.id = rs.skill_id
      left join public.user_skills us on us.skill_id = s.id and us.user_id = p_uid
      where rs.role_id = p_role
        and greatest(rs.required_level - coalesce(us.proficiency, 0), 0) > 0.5
        and not (s.id = any (v_done))
      order by (greatest(rs.required_level - coalesce(us.proficiency, 0), 0) * rs.importance) desc
      limit 1;
      exit when not found;
    end if;

    v_done := array_append(v_done, r.sid);
    skill_id := r.sid;
    skill_name := r.sname;
    gap := r.sgap;
    importance := r.simp;
    difficulty := r.sdiff;
    return next;
  end loop;
end;
$$;

-- Wipe + rebuild (used by reset)
create or replace function public._rebuild_learning_path(p_uid uuid, p_role uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_path_id uuid;
  v_why text[] := '{}';
  r record;
  v_order int := 0;
  v_resource uuid;
begin
  delete from public.learning_paths where user_id = p_uid and role_id = p_role;

  insert into public.learning_paths (user_id, role_id, why_this_path)
  values (p_uid, p_role, '{}')
  returning id into v_path_id;

  for r in select * from public._path_gap_skills(p_uid, p_role)
  loop
    v_order := v_order + 1;

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
      format('%s closes a gap of %s (importance %s). Pass the module quiz (70%%) to unlock the next step.', r.skill_name, r.gap, r.importance),
      null, 0, null
    );

    if cardinality(v_why) < 5 then
      v_why := array_append(v_why, format('%s is gated: study, then pass scenarios to continue.', r.skill_name));
    end if;
  end loop;

  update public.learning_paths set why_this_path = v_why where id = v_path_id;

  return jsonb_build_object(
    'path_id', v_path_id,
    'role_id', p_role,
    'item_count', v_order,
    'why_this_path', to_jsonb(v_why),
    'mode', 'reset'
  );
end;
$$;

-- Create or merge path (preserves completed / in-progress progress)
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
  v_skill uuid;
  v_existing public.path_items;
  v_final uuid[] := '{}';
  v_gap uuid[] := '{}';
  v_hours int;
  v_expl text;
  v_first_incomplete bool := true;
  v_new_status text;
  v_created boolean := false;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select coalesce(p_role_id, target_role_id) into v_role
  from public.profiles where id = v_uid;
  if v_role is null then raise exception 'No target role set'; end if;

  select id into v_path_id
  from public.learning_paths
  where user_id = v_uid and role_id = v_role
  order by created_at desc
  limit 1;

  if v_path_id is null then
    insert into public.learning_paths (user_id, role_id, why_this_path)
    values (v_uid, v_role, '{}')
    returning id into v_path_id;
    v_created := true;
  end if;

  -- Desired gap skills in topo order
  for r in select * from public._path_gap_skills(v_uid, v_role)
  loop
    v_gap := array_append(v_gap, r.skill_id);
  end loop;

  -- Final order: keep completed modules first (by current sort), then remaining gap skills
  for r in
    select pi.skill_id
    from public.path_items pi
    where pi.path_id = v_path_id and pi.status = 'completed'
    order by pi.sort_order
  loop
    v_final := array_append(v_final, r.skill_id);
  end loop;

  foreach v_skill in array v_gap
  loop
    if not (v_skill = any (v_final)) then
      v_final := array_append(v_final, v_skill);
    end if;
  end loop;

  -- Drop incomplete items whose skill is no longer needed
  delete from public.path_items pi
  where pi.path_id = v_path_id
    and pi.status <> 'completed'
    and not (pi.skill_id = any (v_final));

  -- Upsert each skill in final order
  v_order := 0;
  foreach v_skill in array v_final
  loop
    v_order := v_order + 1;

    select
      s.name,
      greatest(coalesce(rs.required_level, 0) - coalesce(us.proficiency, 0), 0) as gap,
      coalesce(rs.importance, 1) as importance,
      least(5, greatest(1, ceil(coalesce(rs.required_level, 2) / 2.0)::int)) as difficulty
    into r
    from public.skills s
    left join public.role_skills rs on rs.skill_id = s.id and rs.role_id = v_role
    left join public.user_skills us on us.skill_id = s.id and us.user_id = v_uid
    where s.id = v_skill;

    select res.id into v_resource
    from public.resources res
    where res.skill_id = v_skill
    order by abs(res.difficulty - coalesce(r.difficulty, 2))
    limit 1;

    v_hours := greatest(2, least(8, ceil(coalesce(r.gap, 1))::int + 2));
    v_expl := format(
      '%s closes a gap of %s (importance %s). Pass the module quiz (70%%) to unlock the next step.',
      r.name, coalesce(r.gap, 0), coalesce(r.importance, 1)
    );

    select * into v_existing
    from public.path_items
    where path_id = v_path_id and skill_id = v_skill
    limit 1;

    if found then
      if v_existing.status = 'completed' then
        v_new_status := 'completed';
      elsif v_first_incomplete then
        v_new_status := case
          when v_existing.status = 'in_progress' then 'in_progress'
          else 'not_started'
        end;
        v_first_incomplete := false;
      else
        v_new_status := 'locked';
      end if;

      update public.path_items set
        sort_order = v_order,
        resource_id = coalesce(v_resource, resource_id),
        estimated_hours = v_hours,
        explanation = v_expl,
        status = v_new_status
      where id = v_existing.id;
    else
      if v_first_incomplete then
        v_new_status := 'not_started';
        v_first_incomplete := false;
      else
        v_new_status := 'locked';
      end if;

      insert into public.path_items (
        path_id, skill_id, resource_id, sort_order, status, estimated_hours, explanation,
        best_score, attempts, passed_at
      ) values (
        v_path_id, v_skill, v_resource, v_order, v_new_status, v_hours, v_expl,
        null, 0, null
      );
    end if;

    if cardinality(v_why) < 5 then
      v_why := array_append(v_why, format('%s is gated: study, then pass scenarios to continue.', r.name));
    end if;
  end loop;

  update public.learning_paths set why_this_path = v_why where id = v_path_id;

  return jsonb_build_object(
    'path_id', v_path_id,
    'role_id', v_role,
    'item_count', v_order,
    'why_this_path', to_jsonb(v_why),
    'mode', case when v_created then 'created' else 'merged' end
  );
end;
$$;

create or replace function public.reset_learning_path(p_role_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select coalesce(p_role_id, target_role_id) into v_role
  from public.profiles where id = v_uid;
  if v_role is null then raise exception 'No target role set'; end if;

  return public._rebuild_learning_path(v_uid, v_role);
end;
$$;

revoke all on function public._path_gap_skills(uuid, uuid) from public, anon, authenticated;
revoke all on function public._rebuild_learning_path(uuid, uuid) from public, anon, authenticated;
grant execute on function public.generate_learning_path(uuid) to authenticated;
grant execute on function public.reset_learning_path(uuid) to authenticated;
