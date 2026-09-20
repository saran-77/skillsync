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

type BatchQ = {
  stem: string
  options: string[]
  correct_index: number
  explanation: string
  skill_id: string
  concept?: string
}

const ANGLES = ['workplace scenario', 'common pitfall', 'debug mystery', 'best practice', 'tradeoff decision', 'API design choice']

function isValid(q: BatchQ, skillIds: Set<string>) {
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

function publicRow(q: Record<string, unknown>) {
  return {
    id: q.id,
    skill_id: q.skill_id,
    difficulty: q.difficulty,
    stem: q.stem,
    options: q.options,
    explanation: q.explanation,
    source: q.source,
    reviewed: q.reviewed,
    concept: q.concept,
  }
}

async function curatedFallback(
  service: ReturnType<typeof createServiceClient>,
  skillIds: string[],
  difficulty: number,
  count: number,
  excludeIds: string[],
) {
  const exclude = new Set(excludeIds)
  const { data } = await service
    .from('questions')
    .select('id, skill_id, difficulty, stem, options, explanation, source, reviewed, concept')
    .in('skill_id', skillIds)
    .eq('source', 'curated')
    .eq('reviewed', true)
    .limit(80)

  const rows = (data || [])
    .filter((r) => !exclude.has(r.id))
    .sort((a, b) => Math.abs(a.difficulty - difficulty) - Math.abs(b.difficulty - difficulty))

  for (let i = rows.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[rows[i], rows[j]] = [rows[j], rows[i]]
  }
  return rows.slice(0, count).map(publicRow)
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
    let skillIds = (Array.isArray(body.skill_ids) ? body.skill_ids : []) as string[]
    if (body.skill_id && !skillIds.length) skillIds = [body.skill_id as string]
    const count = Math.max(1, Math.min(10, Number(body.count) || 1))
    const difficulty = Math.max(1, Math.min(5, Number(body.difficulty) || 3))
    const mode = (body.mode as string) || 'adaptive'
    const excludeIds = (Array.isArray(body.exclude_ids) ? body.exclude_ids : []) as string[]
    const roleTitle = (body.role_title as string) || ''
    const topicHint = (body.topic_hint as string) || ''

    const service = createServiceClient()

    if (!skillIds.length) {
      const { data: skills } = await service.from('skills').select('id').limit(8)
      skillIds = (skills || []).map((s) => s.id)
    }
    if (!skillIds.length) return jsonResponse({ error: 'No skills available' }, 400)

    const { data: skillRows } = await service.from('skills').select('id, name').in('id', skillIds)
    const skills = skillRows || []
    if (!skills.length) return jsonResponse({ error: 'Skills not found' }, 404)
    const skillIdSet = new Set(skills.map((s) => s.id))

    // Recent stems to avoid
    const { data: recentEvents } = await service
      .from('skill_events')
      .select('question_id')
      .eq('user_id', user.id)
      .not('question_id', 'is', null)
      .order('created_at', { ascending: false })
      .limit(50)

    const recentQids = (recentEvents || []).map((e) => e.question_id).filter(Boolean) as string[]
    let recentStems: string[] = []
    if (recentQids.length) {
      const { data: recentQs } = await service.from('questions').select('stem').in('id', recentQids)
      recentStems = (recentQs || []).map((q) => q.stem).slice(0, 20)
    }

    const allExclude = [...new Set([...excludeIds, ...recentQids])]
    const source = mode === 'onboarding' ? 'onboarding' : 'ai'
    const angle = ANGLES[Math.floor(Math.random() * ANGLES.length)]
    const config = await getModelConfig(service, 'quiz_batch')
    const started = Date.now()

    const limits = await checkRateLimits(service, user.id)
    if (!limits.allowed) {
      const fallback = await curatedFallback(service, skillIds, difficulty, count, allExclude)
      if (fallback.length < Math.min(count, 1)) {
        return jsonResponse({ error: 'Daily AI budget exceeded', reason: 'rate_limit' }, 429)
      }
      return jsonResponse({ questions: fallback, source: 'fallback', difficulty, mode })
    }

    try {
      const skillNames = skills.map((s) => `${s.name} (${s.id})`).join('; ')
      const avoid = recentStems.length
        ? `Do NOT repeat or paraphrase these recent stems:\n- ${recentStems.slice(0, 12).join('\n- ')}`
        : 'Make each question distinctive and novel.'

      const res = await callGroq({
        model: config.model,
        max_tokens: Math.max(config.max_tokens || 2048, 1024 + count * 350),
        temperature: 0.75,
        json: true,
        messages: [
          {
            role: 'system',
            content:
              `Return JSON {"questions":[...]} with exactly ${count} unique multiple-choice items. ` +
              'Each item: stem, options (4 strings), correct_index (0-3), explanation, skill_id (UUID from the provided list), concept (short tag). No markdown.',
          },
          {
            role: 'user',
            content: [
              `Mode: ${mode}. Difficulty 1-5: ${difficulty}. Angle focus: ${angle}.`,
              roleTitle ? `Target role: ${roleTitle}.` : '',
              topicHint ? `Topic hint: ${topicHint}.` : '',
              `Skills (use only these skill_id UUIDs): ${skillNames}`,
              avoid,
              'Prefer realistic workplace scenarios. Vary concepts across the set. Never duplicate stems within the set.',
            ]
              .filter(Boolean)
              .join('\n'),
          },
        ],
      })

      const data = await res.json()
      const raw = data.choices?.[0]?.message?.content || '{}'
      const parsed = JSON.parse(raw) as { questions?: BatchQ[] }
      const list = Array.isArray(parsed.questions) ? parsed.questions : []
      const valid = list.filter((q) => isValid(q, skillIdSet)).slice(0, count)

      if (valid.length < Math.min(count, 1)) throw new Error('Too few valid AI questions')

      // Drop near-duplicates of recent stems
      const fresh = valid.filter((q) => {
        const s = q.stem.toLowerCase().slice(0, 40)
        return !recentStems.some((rs) => rs.toLowerCase().includes(s) || s.includes(rs.toLowerCase().slice(0, 40)))
      })
      const finalList = (fresh.length ? fresh : valid).slice(0, count)

      const inserts = finalList.map((q) => ({
        skill_id: q.skill_id,
        difficulty,
        stem: q.stem,
        options: q.options,
        correct_index: q.correct_index,
        explanation: q.explanation,
        source,
        reviewed: true,
        concept: q.concept || mode,
      }))

      const { data: inserted, error } = await service
        .from('questions')
        .insert(inserts)
        .select('id, skill_id, difficulty, stem, options, explanation, source, reviewed, concept')

      if (error || !inserted?.length) throw new Error(error?.message || 'Insert failed')

      await logUsage(
        service,
        user.id,
        'quiz_batch',
        config.model,
        data.usage?.total_tokens || 0,
        Date.now() - started,
        'groq',
      )

      return jsonResponse({
        questions: inserted.map(publicRow),
        source: 'groq',
        difficulty,
        mode,
      })
    } catch (err) {
      console.error(err)
      const fallback = await curatedFallback(service, skillIds, difficulty, count, allExclude)
      await logUsage(service, user.id, 'quiz_batch', config.model, 0, Date.now() - started, 'fallback')
      if (!fallback.length) return jsonResponse({ error: 'Could not generate quiz questions' }, 502)
      return jsonResponse({ questions: fallback, source: 'fallback', difficulty, mode })
    }
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: 'Server error' }, 500)
  }
})
