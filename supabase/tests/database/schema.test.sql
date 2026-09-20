-- RLS smoke checks (run via: npx supabase db reset && psql or supabase test db)
begin;

create extension if not exists pgtap;

select plan(4);

-- Catalog readable structure
select ok(
  (select count(*) > 0 from public.roles),
  'roles seeded'
);

select ok(
  (select count(*) >= 40 from public.questions where source = 'curated'),
  'curated questions seeded'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'questions' and column_name = 'correct_index'
  ),
  'answer key column exists server-side'
);

select ok(
  exists (select 1 from pg_proc where proname = 'submit_assessment'),
  'submit_assessment RPC exists'
);

select * from finish();
rollback;
