import {
  callGroq,
  checkRateLimits,
  corsHeaders,
  createServiceClient,
  fallbackText,
  getCached,
  getModelConfig,
  jsonResponse,
  logUsage,
  requireUser,
  setCache,
  sha256,
} from '../_shared/ai.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const auth = await requireUser(req)
    if ('error' in auth && auth.error) return auth.error

    const { user } = auth as { user: { id: string } }

    const body = await req.json()
    const message = String(body.message || '').slice(0, 2000)
    const mode = (body.mode || 'chat') as 'hint' | 'explain' | 'chat' | 'deeper'
    const skillId = body.skill_id as string | undefined
    const sessionId = body.session_id as string | undefined
    const stream = body.stream !== false

    if (!message) return jsonResponse({ error: 'message required' }, 400)

    const service = createServiceClient()
    const limits = await checkRateLimits(service, user.id)
    if (!limits.allowed) {
      const text = fallbackText(mode)
      return jsonResponse({ text, source: 'fallback', reason: 'rate_limit' }, 429)
    }

    let skillName = ''
    if (skillId) {
      const { data: skill } = await service.from('skills').select('name').eq('id', skillId).maybeSingle()
      skillName = skill?.name || ''
    }

    let sid = sessionId
    if (!sid) {
      const { data: session, error } = await service
        .from('tutor_sessions')
        .insert({
          user_id: user.id,
          skill_id: skillId || null,
          title: skillName ? `${skillName} tutor` : 'Tutor chat',
        })
        .select('id')
        .single()
      if (error) return jsonResponse({ error: error.message }, 500)
      sid = session.id
    } else {
      const { data: owned } = await service
        .from('tutor_sessions')
        .select('id')
        .eq('id', sid)
        .eq('user_id', user.id)
        .maybeSingle()
      if (!owned) return jsonResponse({ error: 'Invalid session' }, 403)
    }

    await service.from('tutor_messages').insert({
      session_id: sid,
      role: 'user',
      content: message,
    })

    const task = mode === 'deeper' ? 'deeper' : mode === 'hint' ? 'hint' : mode === 'explain' ? 'explain' : 'chat'
    const config = await getModelConfig(service, task)
    const system = `You are SkillSync AI, a concise tutoring assistant for students. Mode: ${mode}.
Be accurate, encouraging, and structured. Never invent exam answer keys for scored assessments.
${skillName ? `Focus skill: ${skillName}.` : ''}
Keep answers under 250 words unless the user asks for depth.`

    const promptHash = await sha256(`${task}|${skillName}|${message}`)
    const cached = await getCached(service, promptHash, config.model)
    if (cached) {
      await service.from('tutor_messages').insert({
        session_id: sid,
        role: 'assistant',
        content: cached,
        source: 'cache',
      })
      await logUsage(service, user.id, task, config.model, 0, 0, 'cache')
      return jsonResponse({ text: cached, source: 'cache', session_id: sid })
    }

    const started = Date.now()
    try {
      if (!stream) {
        const res = await callGroq({
          model: config.model,
          max_tokens: config.max_tokens,
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: message },
          ],
        })
        const data = await res.json()
        const text = data.choices?.[0]?.message?.content || fallbackText(mode, skillName)
        const tokens = data.usage?.total_tokens || 0
        await setCache(service, promptHash, config.model, text)
        await service.from('tutor_messages').insert({
          session_id: sid,
          role: 'assistant',
          content: text,
          source: 'groq',
        })
        await logUsage(service, user.id, task, config.model, tokens, Date.now() - started, 'groq')
        return jsonResponse({ text, source: 'groq', session_id: sid })
      }

      const res = await callGroq({
        model: config.model,
        max_tokens: config.max_tokens,
        stream: true,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: message },
        ],
      })

      let full = ''
      const reader = res.body!.getReader()
      const decoder = new TextDecoder()
      const streamOut = new ReadableStream({
        async start(controller) {
          const enc = new TextEncoder()
          controller.enqueue(enc.encode(`data: ${JSON.stringify({ session_id: sid })}\n\n`))
          let buffer = ''
          while (true) {
            const { done, value } = await reader.read()
            if (done) break
            buffer += decoder.decode(value, { stream: true })
            const lines = buffer.split('\n')
            buffer = lines.pop() || ''
            for (const line of lines) {
              const trimmed = line.trim()
              if (!trimmed.startsWith('data:')) continue
              const payload = trimmed.slice(5).trim()
              if (payload === '[DONE]') continue
              try {
                const parsed = JSON.parse(payload)
                const delta = parsed.choices?.[0]?.delta?.content || ''
                if (delta) {
                  full += delta
                  controller.enqueue(enc.encode(`data: ${JSON.stringify({ delta })}\n\n`))
                }
              } catch {
                // ignore partial JSON
              }
            }
          }
          if (!full) full = fallbackText(mode, skillName)
          await setCache(service, promptHash, config.model, full)
          await service.from('tutor_messages').insert({
            session_id: sid,
            role: 'assistant',
            content: full,
            source: 'groq',
          })
          await logUsage(service, user.id, task, config.model, Math.ceil(full.length / 4), Date.now() - started, 'groq')
          controller.enqueue(enc.encode(`data: ${JSON.stringify({ done: true, text: full, source: 'groq' })}\n\n`))
          controller.close()
        },
      })

      return new Response(streamOut, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      })
    } catch (err) {
      console.error(err)
      const text = fallbackText(mode, skillName)
      await service.from('tutor_messages').insert({
        session_id: sid,
        role: 'assistant',
        content: text,
        source: 'fallback',
      })
      await logUsage(service, user.id, task, config.model, 0, Date.now() - started, 'fallback')
      return jsonResponse({ text, source: 'fallback', session_id: sid })
    }
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: 'Server error' }, 500)
  }
})
