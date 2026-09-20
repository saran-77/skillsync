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

type PracticeQuestion = {
  stem: string
  options: string[]
  correct_index: number
  explanation: string
}

function isValid(q: PracticeQuestion) {
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
    q.explanation.length > 4
  )
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
    const skillId = body.skill_id as string
    const difficulty = Math.max(1, Math.min(5, Number(body.difficulty) || 3))
    if (!skillId) return jsonResponse({ error: 'skill_id required' }, 400)

    const service = createServiceClient()
    const limits = await checkRateLimits(service, user.id)
    if (!limits.allowed) {
      return jsonResponse({ error: 'Daily AI budget exceeded', reason: 'rate_limit' }, 429)
    }

    const { data: skill } = await service.from('skills').select('id, name').eq('id', skillId).maybeSingle()
    if (!skill) return jsonResponse({ error: 'Skill not found' }, 404)

    const config = await getModelConfig(service, 'practice_question')
    const started = Date.now()

    try {
      const res = await callGroq({
        model: config.model,
        max_tokens: config.max_tokens,
        json: true,
        messages: [
          {
            role: 'system',
            content:
              'Generate one multiple-choice practice question as JSON with keys: stem, options (array of 4 strings), correct_index (0-3), explanation. No markdown.',
          },
          {
            role: 'user',
            content: `Skill: ${skill.name}. Difficulty 1-5: ${difficulty}. Make it educational for students.`,
          },
        ],
      })
      const data = await res.json()
      const raw = data.choices?.[0]?.message?.content || '{}'
      const parsed = JSON.parse(raw) as PracticeQuestion
      if (!isValid(parsed)) {
        return jsonResponse({ error: 'Invalid generated question' }, 502)
      }

      const { data: inserted, error } = await service
        .from('questions')
        .insert({
          skill_id: skillId,
          difficulty,
          stem: parsed.stem,
          options: parsed.options,
          correct_index: parsed.correct_index,
          explanation: parsed.explanation,
          source: 'ai',
          reviewed: false,
        })
        .select('id, skill_id, difficulty, stem, options, explanation, source, reviewed')
        .single()

      if (error) return jsonResponse({ error: error.message }, 500)

      await logUsage(
        service,
        user.id,
        'practice_question',
        config.model,
        data.usage?.total_tokens || 0,
        Date.now() - started,
        'groq',
      )

      // Return without correct_index for client practice scoring via submit_assessment practice mode
      // Actually practice submit needs server scoring - client should not get key.
      // For immediate practice feedback we score via RPC after answer.
      return jsonResponse({
        question: {
          id: inserted.id,
          skill_id: inserted.skill_id,
          difficulty: inserted.difficulty,
          stem: inserted.stem,
          options: inserted.options,
          explanation: inserted.explanation,
          source: inserted.source,
          reviewed: inserted.reviewed,
        },
      })
    } catch (err) {
      console.error(err)
      // Fallback: curated question
      const { data: fallback } = await service
        .from('questions')
        .select('id, skill_id, difficulty, stem, options, explanation, source, reviewed')
        .eq('skill_id', skillId)
        .eq('source', 'curated')
        .eq('reviewed', true)
        .limit(1)
        .maybeSingle()

      await logUsage(service, user.id, 'practice_question', config.model, 0, Date.now() - started, 'fallback')
      if (!fallback) return jsonResponse({ error: 'Provider failed' }, 502)
      return jsonResponse({ question: fallback, source: 'fallback' })
    }
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: 'Server error' }, 500)
  }
})
