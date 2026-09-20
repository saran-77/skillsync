import {
  callGroq,
  checkRateLimits,
  corsHeaders,
  createServiceClient,
  getModelConfig,
  jsonResponse,
  logUsage,
  requireUser,
} from '../_shared/ai.ts'

type PlacementQ = {
  stem: string
  options: string[]
  correct_index: number
  explanation: string
  skill_id: string
}

function levelToDifficulty(level: string): number {
  switch (level) {
    case 'beginner':
      return 2
    case 'intermediate':
      return 3
    case 'advanced':
      return 4
    case 'pro':
      return 5
    default:
      return 3
  }
}

function isValid(q: PlacementQ, skillIds: Set<string>) {
  return (
    typeof q.stem === 'string' &&
    q.stem.length > 8 &&
    Array.isArray(q.options) &&
    q.options.length === 4 &&
    q.options.every((o) => typeof o === 'string' && o.length > 0) &&
    Number.isInteger(q.correct_index) &&
    q.correct_index >= 0 &&
    q.correct_index <= 3 &&
    typeof q.explanation === 'string' &&
    q.explanation.length > 4 &&
    typeof q.skill_id === 'string' &&
    skillIds.has(q.skill_id)
  )
}

async function curatedFallback(
  service: ReturnType<typeof createServiceClient>,
  skillIds: string[],
  difficulty: number,
) {
  const { data } = await service
    .from('questions')
    .select('id, skill_id, difficulty, stem, options, explanation, source, reviewed, concept')
    .in('skill_id', skillIds)
    .eq('source', 'curated')
    .eq('reviewed', true)
    .order('difficulty')
    .limit(40)

  const rows = data || []
  // Prefer near difficulty, then shuffle-ish by alternating
  const scored = [...rows].sort(
    (a, b) => Math.abs(a.difficulty - difficulty) - Math.abs(b.difficulty - difficulty),
  )
  const picked = scored.slice(0, 5)
  return picked.map((q) => ({
    id: q.id,
    skill_id: q.skill_id,
    difficulty: q.difficulty,
    stem: q.stem,
    options: q.options,
    explanation: q.explanation,
    source: q.source,
    reviewed: q.reviewed,
    concept: q.concept,
  }))
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const auth = await requireUser(req)
    if ('error' in auth && auth.error) return auth.error
    const { user } = auth as { user: { id: string } }

    const body = await req.json()
    const roleId = body.role_id as string
    const skillIds = (Array.isArray(body.skill_ids) ? body.skill_ids : []) as string[]
    const experienceLevel = (body.experience_level as string) || 'beginner'
    const difficulty = levelToDifficulty(experienceLevel)

    if (!roleId || !skillIds.length) {
      return jsonResponse({ error: 'role_id and skill_ids required' }, 400)
    }

    const service = createServiceClient()
    const limits = await checkRateLimits(service, user.id)
    if (!limits.allowed) {
      const fallback = await curatedFallback(service, skillIds, difficulty)
      if (fallback.length < 3) return jsonResponse({ error: 'Daily AI budget exceeded', reason: 'rate_limit' }, 429)
      return jsonResponse({ questions: fallback, source: 'fallback', difficulty })
    }

    const { data: skills } = await service.from('skills').select('id, name').in('id', skillIds)
    const skillList = skills || []
    if (!skillList.length) return jsonResponse({ error: 'Skills not found' }, 404)
    const skillIdSet = new Set(skillList.map((s) => s.id))

    const { data: role } = await service.from('roles').select('id, title').eq('id', roleId).maybeSingle()
    const config = await getModelConfig(service, 'onboarding_placement')
    const started = Date.now()

    try {
      const skillNames = skillList.map((s) => `${s.name} (${s.id})`).join(', ')
      const res = await callGroq({
        model: config.model,
        max_tokens: config.max_tokens || 2048,
        json: true,
        messages: [
          {
            role: 'system',
            content:
              'Return JSON object {"questions":[...]} with exactly 5 multiple-choice items. Each item keys: stem, options (4 strings), correct_index (0-3), explanation, skill_id (must be one of the provided UUIDs). No markdown.',
          },
          {
            role: 'user',
            content: `Placement quiz for aspiring ${role?.title || 'professional'}. Experience: ${experienceLevel} (difficulty ${difficulty}/5). Focus skills: ${skillNames}. Mix concepts; workplace scenario stems preferred.`,
          },
        ],
      })
      const data = await res.json()
      const raw = data.choices?.[0]?.message?.content || '{}'
      const parsed = JSON.parse(raw) as { questions?: PlacementQ[] }
      const list = Array.isArray(parsed.questions) ? parsed.questions : []
      const valid = list.filter((q) => isValid(q, skillIdSet)).slice(0, 5)

      if (valid.length < 3) throw new Error('Too few valid AI questions')

      const inserts = valid.map((q) => ({
        skill_id: q.skill_id,
        difficulty,
        stem: q.stem,
        options: q.options,
        correct_index: q.correct_index,
        explanation: q.explanation,
        source: 'onboarding',
        reviewed: true,
        concept: 'placement',
      }))

      const { data: inserted, error } = await service
        .from('questions')
        .insert(inserts)
        .select('id, skill_id, difficulty, stem, options, explanation, source, reviewed, concept')

      if (error || !inserted?.length) throw new Error(error?.message || 'Insert failed')

      await logUsage(
        service,
        user.id,
        'onboarding_placement',
        config.model,
        data.usage?.total_tokens || 0,
        Date.now() - started,
        'groq',
      )

      return jsonResponse({
        questions: inserted.map((q) => ({
          id: q.id,
          skill_id: q.skill_id,
          difficulty: q.difficulty,
          stem: q.stem,
          options: q.options,
          explanation: q.explanation,
          source: q.source,
          reviewed: q.reviewed,
          concept: q.concept,
        })),
        source: 'groq',
        difficulty,
      })
    } catch (err) {
      console.error(err)
      const fallback = await curatedFallback(service, skillIds, difficulty)
      await logUsage(service, user.id, 'onboarding_placement', config.model, 0, Date.now() - started, 'fallback')
      if (fallback.length < 3) return jsonResponse({ error: 'Could not build placement quiz' }, 502)
      return jsonResponse({ questions: fallback, source: 'fallback', difficulty })
    }
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: 'Server error' }, 500)
  }
})
