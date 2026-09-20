-- Manual RLS verification script (run as service role after creating two users)
-- Example expectations:
-- 1) Authenticated user A cannot select profiles where id = B
-- 2) Authenticated user cannot select questions.correct_index (column privilege)
-- 3) submit_assessment only writes assessments for auth.uid()

select 'See README Testing section for end-to-end auth RLS checks' as note;
