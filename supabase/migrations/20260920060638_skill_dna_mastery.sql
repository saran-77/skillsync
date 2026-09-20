-- Skill DNA + Mastery Engine

alter table public.questions add column if not exists concept text;

create or replace view public.questions_public
with (security_invoker = true) as
select
  id, skill_id, difficulty, stem, options, explanation, source, reviewed, created_at, concept
from public.questions
where reviewed = true;

revoke all on table public.questions from anon, authenticated;
grant select (
  id, skill_id, difficulty, stem, options, explanation, source, reviewed, created_at, concept
) on table public.questions to authenticated;
grant select on public.questions_public to authenticated;
grant all on table public.questions to service_role, postgres;

update public.questions set concept = 'functions'
  where concept is null and stem ilike '%function%';
update public.questions set concept = 'collections'
  where concept is null and (stem ilike '%list%' or stem ilike '%tuple%' or stem ilike '%len(%');
update public.questions set concept = 'booleans'
  where concept is null and stem ilike '%bool%';
update public.questions set concept = 'args'
  where concept is null and stem ilike '%*args%';
update public.questions set concept = 'filtering'
  where concept is null and (stem ilike '%where%' or stem ilike '%having%');
update public.questions set concept = 'joins'
  where concept is null and stem ilike '%join%';
update public.questions set concept = 'aggregates'
  where concept is null and stem ilike '%distinct%';
update public.questions set concept = 'transactions'
  where concept is null and stem ilike '%isolation%';
update public.questions set concept = 'descriptive-stats'
  where concept is null and (stem ilike '%mean%' or stem ilike '%median%' or stem ilike '%variance%');
update public.questions set concept = 'inference'
  where concept is null and (stem ilike '%p-value%' or stem ilike '%correlation%');
update public.questions set concept = 'charts'
  where concept is null and (stem ilike '%chart%' or stem ilike '%histogram%' or stem ilike '%pie%' or stem ilike '%line chart%' or stem ilike '%y-axes%' or stem ilike '%colorblind%');
update public.questions set concept = 'semantics'
  where concept is null and (stem ilike '%hyperlink%' or stem ilike '%semantic%' or stem ilike '%rem %' or stem ilike '%box model%' or stem ilike '%flexbox%');
update public.questions set concept = 'language-basics'
  where concept is null and skill_id = '22222222-2222-2222-2222-222222220006'::uuid;
update public.questions set concept = 'react-fundamentals'
  where concept is null and skill_id = '22222222-2222-2222-2222-222222220007'::uuid;
update public.questions set concept = 'http-rest'
  where concept is null and skill_id = '22222222-2222-2222-2222-222222220008'::uuid;
update public.questions set concept = 'data-modeling'
  where concept is null and skill_id = '22222222-2222-2222-2222-222222220009'::uuid;
update public.questions set concept = 'security-basics'
  where concept is null and skill_id = '22222222-2222-2222-2222-222222220010'::uuid;
update public.questions set concept = 'fundamentals'
  where concept is null;

create table if not exists public.skill_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  question_id uuid references public.questions(id) on delete set null,
  event_type text not null check (event_type in (
    'assessment', 'practice', 'daily', 'interview', 'flashcard', 'challenge'
  )),
  correct boolean,
  score numeric(6,2),
  difficulty int check (difficulty between 1 and 5),
  time_taken_seconds numeric(10,2),
  confidence int,
  concept text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_skill_events_user_skill on public.skill_events(user_id, skill_id, created_at desc);
create index if not exists idx_skill_events_user_created on public.skill_events(user_id, created_at desc);

create table if not exists public.skill_mastery (
  user_id uuid not null references auth.users(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  mastery_score numeric(6,2) not null default 0 check (mastery_score between 0 and 100),
  confidence numeric(6,2) not null default 0 check (confidence between 0 and 100),
  retention_score numeric(6,2) not null default 100 check (retention_score between 0 and 100),
  accuracy_recent numeric(6,2) not null default 0 check (accuracy_recent between 0 and 100),
  speed_score numeric(6,2) not null default 50 check (speed_score between 0 and 100),
  consistency_score numeric(6,2) not null default 0 check (consistency_score between 0 and 100),
  evidence_count int not null default 0,
  last_practiced_at timestamptz,
  trend text not null default 'flat' check (trend in ('up', 'flat', 'down')),
  diagnosis text,
  updated_at timestamptz not null default now(),
  primary key (user_id, skill_id)
);

alter table public.skill_events enable row level security;
alter table public.skill_mastery enable row level security;

drop policy if exists skill_events_select on public.skill_events;
create policy skill_events_select on public.skill_events for select to authenticated
  using (user_id = auth.uid());

drop policy if exists skill_mastery_select on public.skill_mastery;
create policy skill_mastery_select on public.skill_mastery for select to authenticated
  using (user_id = auth.uid());

create or replace function public.recompute_skill_mastery(p_user_id uuid, p_skill_id uuid)
returns public.skill_mastery
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.skill_mastery;
  v_count int := 0;
  v_correct int := 0;
  v_avg_time numeric := 0;
  v_avg_conf numeric := 3;
  v_avg_diff numeric := 3;
  v_first_acc numeric := 0;
  v_second_acc numeric := 0;
  v_half int;
  v_days numeric := 0;
  v_last timestamptz;
  v_mastery numeric := 0;
  v_confidence numeric := 0;
  v_retention numeric := 100;
  v_speed numeric := 50;
  v_consistency numeric := 0;
  v_accuracy numeric := 0;
  v_trend text := 'flat';
  v_diagnosis text;
  v_wrong_fast int := 0;
  v_wrong_slow int := 0;
  v_wrong_high_conf int := 0;
begin
  select count(*),
         count(*) filter (where correct is true),
         coalesce(avg(time_taken_seconds) filter (where time_taken_seconds is not null), 0),
         coalesce(avg(confidence) filter (where confidence is not null), 3),
         coalesce(avg(difficulty), 3),
         max(created_at)
    into v_count, v_correct, v_avg_time, v_avg_conf, v_avg_diff, v_last
  from (
    select *
    from public.skill_events
    where user_id = p_user_id
      and skill_id = p_skill_id
      and created_at >= now() - interval '14 days'
    order by created_at desc
    limit 30
  ) e;

  if v_count = 0 then
    select * into v_row from public.skill_mastery where user_id = p_user_id and skill_id = p_skill_id;
    if found then
      v_days := greatest(0, extract(epoch from (now() - coalesce(v_row.last_practiced_at, now()))) / 86400.0 - 2);
      v_retention := greatest(20, v_row.retention_score - (v_days * 2));
      update public.skill_mastery
      set retention_score = v_retention,
          confidence = greatest(0, confidence - (v_days * 0.5)),
          updated_at = now()
      where user_id = p_user_id and skill_id = p_skill_id
      returning * into v_row;
      return v_row;
    end if;
    return null;
  end if;

  v_accuracy := round((v_correct::numeric / v_count::numeric) * 100, 2);
  v_mastery := round(least(100, (v_accuracy * 0.7) + (v_avg_diff * 6)), 2);

  v_confidence := round(least(100,
    (least(v_count, 20)::numeric / 20.0) * 40
    + (v_accuracy * 0.4)
    + greatest(0, 20 - abs(v_avg_conf - 3) * 5)
  ), 2);

  v_days := greatest(0, extract(epoch from (now() - coalesce(v_last, now()))) / 86400.0 - 2);
  v_retention := greatest(20, round(100 - (v_days * 2) - ((100 - v_accuracy) * 0.15), 2));

  v_speed := round(least(100, greatest(0,
    50 + ((coalesce(v_avg_diff, 3) * 15) - coalesce(v_avg_time, 15)) * 2
  )), 2);

  v_half := greatest(1, v_count / 2);

  select coalesce(avg(case when correct then 100 else 0 end), 0)
  into v_first_acc
  from (
    select correct from public.skill_events
    where user_id = p_user_id and skill_id = p_skill_id
      and created_at >= now() - interval '14 days'
    order by created_at asc
    limit v_half
  ) a;

  select coalesce(avg(case when correct then 100 else 0 end), 0)
  into v_second_acc
  from (
    select correct from public.skill_events
    where user_id = p_user_id and skill_id = p_skill_id
      and created_at >= now() - interval '14 days'
    order by created_at desc
    limit v_half
  ) b;

  v_consistency := round(100 - least(100, abs(v_second_acc - v_first_acc)), 2);

  if v_second_acc - v_first_acc >= 8 then
    v_trend := 'up';
  elsif v_first_acc - v_second_acc >= 8 then
    v_trend := 'down';
  else
    v_trend := 'flat';
  end if;

  select
    count(*) filter (where correct is false and coalesce(time_taken_seconds, 20) < 8),
    count(*) filter (where correct is false and coalesce(time_taken_seconds, 20) > 40),
    count(*) filter (where correct is false and coalesce(confidence, 3) >= 4)
  into v_wrong_fast, v_wrong_slow, v_wrong_high_conf
  from public.skill_events
  where user_id = p_user_id and skill_id = p_skill_id
    and created_at >= now() - interval '14 days';

  if v_retention < 45 and v_accuracy >= 60 then
    v_diagnosis := 'Retention drop: you knew this before — revise soon to lock it in.';
  elsif v_wrong_high_conf > 0 and v_accuracy < 55 then
    v_diagnosis := 'Careless pattern: high confidence on misses — slow down and eliminate options.';
  elsif v_wrong_slow > 0 and v_accuracy < 55 then
    v_diagnosis := 'Concept gap: slow and incorrect — revisit fundamentals before harder items.';
  elsif v_wrong_fast > 0 and v_accuracy < 60 then
    v_diagnosis := 'Speed errors: rushing leads to misses — prioritize accuracy over pace.';
  elsif v_accuracy < 50 then
    v_diagnosis := 'Concept gap: accuracy is low — focus path items and worked examples.';
  elsif v_trend = 'up' then
    v_diagnosis := 'Improving: keep practicing at the current difficulty band.';
  else
    v_diagnosis := 'Stable: maintain with short revision and one harder challenge.';
  end if;

  insert into public.skill_mastery (
    user_id, skill_id, mastery_score, confidence, retention_score,
    accuracy_recent, speed_score, consistency_score, evidence_count,
    last_practiced_at, trend, diagnosis, updated_at
  ) values (
    p_user_id, p_skill_id, v_mastery, v_confidence, v_retention,
    v_accuracy, v_speed, v_consistency, v_count,
    v_last, v_trend, v_diagnosis, now()
  )
  on conflict (user_id, skill_id) do update set
    mastery_score = excluded.mastery_score,
    confidence = excluded.confidence,
    retention_score = excluded.retention_score,
    accuracy_recent = excluded.accuracy_recent,
    speed_score = excluded.speed_score,
    consistency_score = excluded.consistency_score,
    evidence_count = excluded.evidence_count,
    last_practiced_at = excluded.last_practiced_at,
    trend = excluded.trend,
    diagnosis = excluded.diagnosis,
    updated_at = now()
  returning * into v_row;

  insert into public.user_skills (user_id, skill_id, proficiency, updated_at)
  values (p_user_id, p_skill_id, round(v_mastery / 10.0, 2), now())
  on conflict (user_id, skill_id) do update
    set proficiency = round(excluded.proficiency, 2),
        updated_at = now();

  return v_row;
end;
$$;

create or replace function public.record_skill_event(
  p_user_id uuid,
  p_skill_id uuid,
  p_event_type text,
  p_question_id uuid default null,
  p_correct boolean default null,
  p_score numeric default null,
  p_difficulty int default null,
  p_time_taken numeric default null,
  p_confidence int default null,
  p_concept text default null,
  p_meta jsonb default '{}'::jsonb
)
returns public.skill_mastery
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'Forbidden';
  end if;

  insert into public.skill_events (
    user_id, skill_id, question_id, event_type, correct, score,
    difficulty, time_taken_seconds, confidence, concept, meta
  ) values (
    p_user_id, p_skill_id, p_question_id, p_event_type, p_correct, p_score,
    p_difficulty, p_time_taken, p_confidence, p_concept, coalesce(p_meta, '{}'::jsonb)
  );
  return public.recompute_skill_mastery(p_user_id, p_skill_id);
end;
$$;

-- Patch submit_assessment to emit skill events
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
  v_concept text;
  v_diff int;
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

  if v_card.skill_id is not null then
    select concept, difficulty into v_concept, v_diff
    from public.questions where id = v_card.question_id;

    perform public.record_skill_event(
      v_uid,
      v_card.skill_id,
      'flashcard',
      v_card.question_id,
      (p_quality >= 3),
      (p_quality * 20)::numeric,
      coalesce(v_diff, 3),
      null,
      p_quality,
      v_concept,
      jsonb_build_object('flashcard_id', v_card.id, 'quality', p_quality)
    );
  end if;

  return v_card;
end;
$$;

create or replace function public.get_skill_dna(p_skill_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_skills jsonb;
  v_concepts jsonb;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  -- apply light decay pass
  perform public.recompute_skill_mastery(v_uid, sm.skill_id)
  from public.skill_mastery sm
  where sm.user_id = v_uid
    and (p_skill_id is null or sm.skill_id = p_skill_id);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.mastery_score desc), '[]'::jsonb)
  into v_skills
  from (
    select
      sm.skill_id,
      s.name as skill_name,
      s.slug,
      sm.mastery_score,
      sm.confidence,
      sm.retention_score,
      sm.accuracy_recent,
      sm.speed_score,
      sm.consistency_score,
      sm.evidence_count,
      sm.last_practiced_at,
      sm.trend,
      sm.diagnosis,
      (
        select count(*) from public.skill_events se
        where se.user_id = v_uid and se.skill_id = sm.skill_id and se.event_type = 'assessment'
      ) as assessment_events,
      (
        select count(*) from public.skill_events se
        where se.user_id = v_uid and se.skill_id = sm.skill_id and se.event_type = 'flashcard'
      ) as flashcard_events,
      (
        select count(*) from public.skill_events se
        where se.user_id = v_uid and se.skill_id = sm.skill_id and se.event_type in ('practice', 'daily')
      ) as practice_events
    from public.skill_mastery sm
    join public.skills s on s.id = sm.skill_id
    where sm.user_id = v_uid
      and (p_skill_id is null or sm.skill_id = p_skill_id)
  ) x;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.accuracy asc), '[]'::jsonb)
  into v_concepts
  from (
    select
      se.skill_id,
      s.name as skill_name,
      coalesce(se.concept, 'general') as concept,
      round(avg(case when se.correct then 100 else 0 end), 1) as accuracy,
      count(*) as attempts,
      case
        when avg(case when se.correct then 100 else 0 end) < 50 then 'down'
        when avg(case when se.correct then 100 else 0 end) > 75 then 'up'
        else 'flat'
      end as trend
    from public.skill_events se
    join public.skills s on s.id = se.skill_id
    where se.user_id = v_uid
      and (p_skill_id is null or se.skill_id = p_skill_id)
      and se.created_at >= now() - interval '30 days'
    group by se.skill_id, s.name, coalesce(se.concept, 'general')
    having count(*) >= 1
  ) c;

  return jsonb_build_object(
    'skills', v_skills,
    'concepts', v_concepts
  );
end;
$$;

create or replace function public.get_todays_mission()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_items jsonb := '[]'::jsonb;
  v_role uuid;
  r record;
  v_minutes int := 0;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select target_role_id into v_role from public.profiles where id = v_uid;

  -- decay refresh
  perform public.recompute_skill_mastery(v_uid, sm.skill_id)
  from public.skill_mastery sm where sm.user_id = v_uid;

  for r in
    select sm.skill_id, s.name, sm.retention_score, sm.diagnosis, 'revise' as kind,
           format('Retention for %s is %s%%.', s.name, round(sm.retention_score)) as why,
           5 as minutes
    from public.skill_mastery sm
    join public.skills s on s.id = sm.skill_id
    where sm.user_id = v_uid and sm.retention_score < 70
    order by sm.retention_score asc
    limit 2
  loop
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'kind', r.kind,
      'skill_id', r.skill_id,
      'title', format('Revise %s', r.name),
      'why', r.why,
      'minutes', r.minutes,
      'href', '/flashcards'
    ));
    v_minutes := v_minutes + r.minutes;
  end loop;

  if v_role is not null then
    for r in
      select s.id as skill_id, s.name,
             greatest(rs.required_level - coalesce(us.proficiency, 0), 0) as gap,
             rs.importance
      from public.role_skills rs
      join public.skills s on s.id = rs.skill_id
      left join public.user_skills us on us.skill_id = s.id and us.user_id = v_uid
      where rs.role_id = v_role
        and greatest(rs.required_level - coalesce(us.proficiency, 0), 0) >= 2
      order by (greatest(rs.required_level - coalesce(us.proficiency, 0), 0) * rs.importance) desc
      limit 1
    loop
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'kind', 'practice',
        'skill_id', r.skill_id,
        'title', format('Practice 3 %s questions', r.name),
        'why', format('Closes a gap of %s toward your target role.', r.gap),
        'minutes', 8,
        'href', '/assessment'
      ));
      v_minutes := v_minutes + 8;
    end loop;
  end if;

  if exists (
    select 1 from public.flashcards f
    where f.user_id = v_uid and f.due_at <= now()
  ) then
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'kind', 'flashcards',
      'title', 'Clear due flashcards',
      'why', 'Spaced review of recent mistakes.',
      'minutes', 5,
      'href', '/flashcards'
    ));
    v_minutes := v_minutes + 5;
  end if;

  if not exists (
    select 1 from public.daily_challenges dc
    where dc.user_id = v_uid and dc.challenge_date = current_date and dc.completed
  ) then
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'kind', 'daily',
      'title', 'Complete daily challenge',
      'why', 'Keep consistency and streak alive.',
      'minutes', 5,
      'href', '/challenge'
    ));
    v_minutes := v_minutes + 5;
  end if;

  -- trim to 4
  if jsonb_array_length(v_items) > 4 then
    select jsonb_agg(elem)
    into v_items
    from (
      select elem from jsonb_array_elements(v_items) with ordinality as t(elem, ord)
      where ord <= 4
    ) x;
    v_minutes := least(v_minutes, 24);
  end if;

  if jsonb_array_length(v_items) = 0 then
    v_items := jsonb_build_array(jsonb_build_object(
      'kind', 'assess',
      'title', 'Take an adaptive assessment',
      'why', 'Build your Skill DNA with fresh evidence.',
      'minutes', 12,
      'href', '/assessment'
    ));
    v_minutes := 12;
  end if;

  return jsonb_build_object(
    'total_minutes', v_minutes,
    'items', v_items
  );
end;
$$;

create or replace function public.get_next_difficulty(p_skill_id uuid default null)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_base int := 3;
  v_streak_correct int := 0;
  v_streak_wrong int := 0;
  r record;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  if p_skill_id is not null then
    select greatest(1, least(5, round(coalesce(sm.mastery_score, 50) / 20.0)::int))
    into v_base
    from public.skill_mastery sm
    where sm.user_id = v_uid and sm.skill_id = p_skill_id;
    if not found then v_base := 3; end if;
  end if;

  for r in
    select correct
    from public.skill_events
    where user_id = v_uid
      and (p_skill_id is null or skill_id = p_skill_id)
      and correct is not null
    order by created_at desc
    limit 5
  loop
    if r.correct then
      if v_streak_wrong > 0 then exit; end if;
      v_streak_correct := v_streak_correct + 1;
    else
      if v_streak_correct > 0 then exit; end if;
      v_streak_wrong := v_streak_wrong + 1;
    end if;
  end loop;

  if v_streak_correct >= 2 then
    v_base := v_base + 1;
  elsif v_streak_wrong >= 2 then
    v_base := v_base - 1;
  end if;

  return greatest(1, least(5, v_base));
end;
$$;

-- Backfill events from existing assessment answers
insert into public.skill_events (
  user_id, skill_id, question_id, event_type, correct, score, difficulty,
  time_taken_seconds, confidence, concept, meta, created_at
)
select
  a.user_id,
  q.skill_id,
  aa.question_id,
  case a.mode
    when 'practice' then 'practice'
    when 'daily' then 'daily'
    when 'interview' then 'interview'
    else 'assessment'
  end,
  aa.is_correct,
  case when aa.is_correct then 100 else 0 end,
  q.difficulty,
  case when a.time_taken_seconds > 0 and cnt.c > 0 then a.time_taken_seconds / cnt.c else null end,
  aa.confidence,
  q.concept,
  jsonb_build_object('assessment_id', a.id, 'backfill', true),
  coalesce(aa.answered_at, a.completed_at, a.started_at, now())
from public.assessment_answers aa
join public.assessments a on a.id = aa.assessment_id
join public.questions q on q.id = aa.question_id
join lateral (
  select count(*)::numeric as c from public.assessment_answers x where x.assessment_id = a.id
) cnt on true
where not exists (
  select 1 from public.skill_events se
  where se.user_id = a.user_id
    and se.question_id = aa.question_id
    and se.meta->>'assessment_id' = a.id::text
);

-- Recompute mastery for all users/skills that have events
do $$
declare
  r record;
begin
  for r in
    select distinct user_id, skill_id from public.skill_events
  loop
    perform public.recompute_skill_mastery(r.user_id, r.skill_id);
  end loop;
end $$;

grant execute on function public.recompute_skill_mastery(uuid, uuid) to authenticated;
grant execute on function public.record_skill_event(uuid, uuid, text, uuid, boolean, numeric, int, numeric, int, text, jsonb) to authenticated;
grant execute on function public.get_skill_dna(uuid) to authenticated;
grant execute on function public.get_todays_mission() to authenticated;
grant execute on function public.get_next_difficulty(uuid) to authenticated;
grant execute on function public.submit_assessment(text, jsonb, numeric, text) to authenticated;
grant execute on function public.review_flashcard(uuid, int) to authenticated;
