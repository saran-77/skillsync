# SkillSync AI

Adaptive learning platform for students: assess skills, close gaps for a target role, follow a learning path, and chat with an AI tutor.

**Stack:** React (Vite) + Supabase (Auth, Postgres/RLS, Edge Functions) + Groq

## Features

- Adaptive assessments with server-side scoring (answer keys never hit the browser)
- Gap analysis vs role requirements
- Personalized learning path with study timer + bookmarks
- AI tutor (Groq) with rate limits, cache, and template fallback
- Daily challenge, flashcards from wrong answers, interview mode, AI practice questions

## Quick start (hosted Supabase free)

1. Create a project at [supabase.com](https://supabase.com)
2. Install CLI deps and link:

```bash
npm install
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
```

3. Copy Project URL + `anon` key into `.env`:

```bash
cp .env.example .env
# VITE_SUPABASE_URL=https://xxxx.supabase.co
# VITE_SUPABASE_ANON_KEY=eyJ...
```

4. Set Groq secret and deploy functions:

```bash
npx supabase secrets set GROQ_API_KEY=gsk_your_key
npx supabase functions deploy ai-tutor
npx supabase functions deploy generate-practice-question
```

5. Run the app:

```bash
npm run dev
```

## Local Supabase (optional)

Requires **Docker Desktop** (or Podman) on PATH.

```bash
npx supabase start
npx supabase status   # copy URL + anon key to .env
npx supabase db reset
npx supabase functions serve
```

For easier signup during development, disable **Confirm email** under Authentication → Providers → Email in the Supabase dashboard.

## Privacy

Tutor messages are sent to Groq (third party). Do not paste secrets or personal data into the tutor. Scored assessments use curated questions only; AI-generated items are practice-only (`reviewed=false`) and are never mixed into adaptive scoring banks until reviewed.

## AI limits (free-tier friendly)

- 30 requests / user / day
- 5 requests / user / minute
- Cache + template fallback when quota or Groq fails

## Testing

- Schema smoke: [`supabase/tests/database/schema.test.sql`](supabase/tests/database/schema.test.sql) (pgTAP; needs local DB)
- Manual RLS notes: [`supabase/tests/rls_manual.sql`](supabase/tests/rls_manual.sql)
- Frontend: `npm run build`

## Project layout

```
src/                 React app (pages, auth, supabase client)
supabase/migrations Schema, RLS, RPCs, seed catalog
supabase/functions   ai-tutor, generate-practice-question
```
