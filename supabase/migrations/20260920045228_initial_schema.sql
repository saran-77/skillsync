-- SkillSync AI: core schema, RLS, profile trigger
create extension if not exists "pgcrypto";

create schema if not exists app;
revoke all on schema app from public;
grant usage on schema app to postgres, service_role;

-- Catalog
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);

create table public.skills (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  category text not null default 'general',
  prerequisites uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

create table public.role_skills (
  role_id uuid not null references public.roles(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  required_level numeric(4,2) not null default 5 check (required_level between 0 and 10),
  importance int not null default 3 check (importance between 1 and 5),
  primary key (role_id, skill_id)
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  skill_id uuid not null references public.skills(id) on delete cascade,
  difficulty int not null default 3 check (difficulty between 1 and 5),
  stem text not null,
  options jsonb not null,
  correct_index int not null check (correct_index between 0 and 3),
  explanation text not null default '',
  source text not null default 'curated' check (source in ('curated', 'ai')),
  reviewed boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.resources (
  id uuid primary key default gen_random_uuid(),
  skill_id uuid not null references public.skills(id) on delete cascade,
  title text not null,
  url text not null,
  type text not null default 'article',
  difficulty int not null default 2 check (difficulty between 1 and 5),
  created_at timestamptz not null default now()
);

-- Profiles
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  target_role_id uuid references public.roles(id),
  experience_level text not null default 'beginner'
    check (experience_level in ('beginner', 'intermediate', 'advanced')),
  streak_count int not null default 0,
  last_active_date date,
  xp int not null default 0,
  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mode text not null default 'adaptive' check (mode in ('adaptive', 'interview', 'daily', 'practice')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  score numeric(5,2),
  level text,
  topic text,
  time_taken_seconds numeric(10,2) default 0
);

create table public.assessment_answers (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  selected_index int,
  is_correct boolean,
  confidence int default 3,
  answered_at timestamptz not null default now()
);

create table public.user_skills (
  user_id uuid not null references auth.users(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  proficiency numeric(4,2) not null default 0 check (proficiency between 0 and 10),
  updated_at timestamptz not null default now(),
  primary key (user_id, skill_id)
);

create table public.user_skill_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  proficiency numeric(4,2) not null,
  recorded_at timestamptz not null default now()
);

create table public.learning_paths (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  why_this_path text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (user_id, role_id)
);

create table public.path_items (
  id uuid primary key default gen_random_uuid(),
  path_id uuid not null references public.learning_paths(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  resource_id uuid references public.resources(id) on delete set null,
  sort_order int not null default 0,
  status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'completed')),
  estimated_hours int not null default 4,
  explanation text not null default '',
  unique (path_id, skill_id)
);

create table public.tutor_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  skill_id uuid references public.skills(id) on delete set null,
  title text not null default 'Tutor chat',
  created_at timestamptz not null default now()
);

create table public.tutor_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.tutor_sessions(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  source text,
  created_at timestamptz not null default now()
);

create table public.flashcards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  question_id uuid references public.questions(id) on delete set null,
  skill_id uuid references public.skills(id) on delete set null,
  front text not null,
  back text not null,
  due_at timestamptz not null default now(),
  interval_days int not null default 1,
  ease numeric(4,2) not null default 2.5,
  created_at timestamptz not null default now()
);

create table public.daily_challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_date date not null default current_date,
  assessment_id uuid references public.assessments(id) on delete set null,
  score numeric(5,2),
  completed boolean not null default false,
  unique (user_id, challenge_date)
);

create table public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  path_item_id uuid references public.path_items(id) on delete set null,
  minutes numeric(8,2) not null default 0,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create table public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  resource_id uuid not null references public.resources(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, resource_id)
);

create table public.ai_cache (
  id uuid primary key default gen_random_uuid(),
  prompt_hash text not null,
  model text not null,
  prompt_version text not null default 'v1',
  response text not null,
  created_at timestamptz not null default now(),
  unique (prompt_hash, model, prompt_version)
);

create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task text not null,
  model text,
  tokens int not null default 0,
  latency_ms int,
  source text not null default 'groq',
  created_at timestamptz not null default now()
);

create table public.model_config (
  task text primary key,
  model text not null,
  max_tokens int not null default 512,
  updated_at timestamptz not null default now()
);

insert into public.model_config (task, model, max_tokens) values
  ('hint', 'llama-3.1-8b-instant', 256),
  ('explain', 'llama-3.1-8b-instant', 512),
  ('chat', 'llama-3.1-8b-instant', 768),
  ('practice_question', 'llama-3.3-70b-versatile', 1024),
  ('deeper', 'llama-3.3-70b-versatile', 1024);

-- Public question view (no answer key)
create or replace view public.questions_public
with (security_invoker = true) as
select
  id, skill_id, difficulty, stem, options, explanation, source, reviewed, created_at
from public.questions
where reviewed = true;

-- Profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS
alter table public.roles enable row level security;
alter table public.skills enable row level security;
alter table public.role_skills enable row level security;
alter table public.questions enable row level security;
alter table public.resources enable row level security;
alter table public.profiles enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_answers enable row level security;
alter table public.user_skills enable row level security;
alter table public.user_skill_history enable row level security;
alter table public.learning_paths enable row level security;
alter table public.path_items enable row level security;
alter table public.tutor_sessions enable row level security;
alter table public.tutor_messages enable row level security;
alter table public.flashcards enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.study_sessions enable row level security;
alter table public.bookmarks enable row level security;
alter table public.ai_cache enable row level security;
alter table public.ai_usage enable row level security;
alter table public.model_config enable row level security;

-- Catalog: authenticated read
create policy roles_select on public.roles for select to authenticated using (true);
create policy skills_select on public.skills for select to authenticated using (true);
create policy role_skills_select on public.role_skills for select to authenticated using (true);
create policy resources_select on public.resources for select to authenticated using (true);
create policy model_config_select on public.model_config for select to authenticated using (true);

-- Questions: RLS allows row access; column GRANT hides correct_index
create policy questions_select on public.questions for select to authenticated
  using (reviewed = true);

create policy profiles_select on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy assessments_all on public.assessments for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy assessment_answers_select on public.assessment_answers for select to authenticated
  using (exists (select 1 from public.assessments a where a.id = assessment_id and a.user_id = auth.uid()));
create policy assessment_answers_insert on public.assessment_answers for insert to authenticated
  with check (exists (select 1 from public.assessments a where a.id = assessment_id and a.user_id = auth.uid()));

create policy user_skills_all on public.user_skills for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy user_skill_history_select on public.user_skill_history for select to authenticated
  using (user_id = auth.uid());

create policy learning_paths_all on public.learning_paths for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy path_items_select on public.path_items for select to authenticated
  using (exists (select 1 from public.learning_paths lp where lp.id = path_id and lp.user_id = auth.uid()));
create policy path_items_update on public.path_items for update to authenticated
  using (exists (select 1 from public.learning_paths lp where lp.id = path_id and lp.user_id = auth.uid()));

create policy tutor_sessions_all on public.tutor_sessions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy tutor_messages_select on public.tutor_messages for select to authenticated
  using (exists (select 1 from public.tutor_sessions s where s.id = session_id and s.user_id = auth.uid()));
create policy tutor_messages_insert on public.tutor_messages for insert to authenticated
  with check (exists (select 1 from public.tutor_sessions s where s.id = session_id and s.user_id = auth.uid()));

create policy flashcards_all on public.flashcards for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy daily_challenges_all on public.daily_challenges for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy study_sessions_all on public.study_sessions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy bookmarks_all on public.bookmarks for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy ai_usage_select on public.ai_usage for select to authenticated
  using (user_id = auth.uid());

-- Hide answer keys from clients (column privileges)
revoke all on table public.questions from anon, authenticated;
grant select (
  id, skill_id, difficulty, stem, options, explanation, source, reviewed, created_at
) on table public.questions to authenticated;
grant select on public.questions_public to authenticated;
grant all on table public.questions to service_role, postgres;

-- Indexes
create index idx_questions_skill_diff on public.questions(skill_id, difficulty);
create index idx_user_skills_user on public.user_skills(user_id);
create index idx_assessments_user on public.assessments(user_id);
create index idx_ai_usage_user_day on public.ai_usage(user_id, created_at);
create index idx_flashcards_due on public.flashcards(user_id, due_at);
