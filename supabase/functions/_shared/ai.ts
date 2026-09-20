import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

export function createServiceClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
}

export function createUserClient(authHeader: string) {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )
}

export async function requireUser(req: Request) {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return { error: jsonResponse({ error: 'Unauthorized' }, 401) }
  const supabase = createUserClient(authHeader)
  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return { error: jsonResponse({ error: 'Unauthorized' }, 401) }
  return { user, authHeader, supabase }
}

const DAILY_LIMIT = 80
const MINUTE_LIMIT = 15

export async function checkRateLimits(service: ReturnType<typeof createServiceClient>, userId: string) {
  const sinceDay = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const sinceMinute = new Date(Date.now() - 60 * 1000).toISOString()

  const { count: dayCount } = await service
    .from('ai_usage')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', sinceDay)

  const { count: minuteCount } = await service
    .from('ai_usage')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', sinceMinute)

  if ((dayCount ?? 0) >= DAILY_LIMIT || (minuteCount ?? 0) >= MINUTE_LIMIT) {
    return { allowed: false as const, reason: 'rate_limit' }
  }
  return { allowed: true as const }
}

export async function getModelConfig(service: ReturnType<typeof createServiceClient>, task: string) {
  const { data } = await service.from('model_config').select('*').eq('task', task).maybeSingle()
  return data ?? { task, model: 'llama-3.1-8b-instant', max_tokens: 512 }
}

export async function sha256(text: string) {
  const data = new TextEncoder().encode(text)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

export async function getCached(
  service: ReturnType<typeof createServiceClient>,
  promptHash: string,
  model: string,
) {
  const { data } = await service
    .from('ai_cache')
    .select('response')
    .eq('prompt_hash', promptHash)
    .eq('model', model)
    .eq('prompt_version', 'v1')
    .maybeSingle()
  return data?.response ?? null
}

export async function setCache(
  service: ReturnType<typeof createServiceClient>,
  promptHash: string,
  model: string,
  response: string,
) {
  await service.from('ai_cache').upsert({
    prompt_hash: promptHash,
    model,
    prompt_version: 'v1',
    response,
  }, { onConflict: 'prompt_hash,model,prompt_version' })
}

export async function logUsage(
  service: ReturnType<typeof createServiceClient>,
  userId: string,
  task: string,
  model: string,
  tokens: number,
  latencyMs: number,
  source: string,
) {
  await service.from('ai_usage').insert({
    user_id: userId,
    task,
    model,
    tokens,
    latency_ms: latencyMs,
    source,
  })
}

export async function callGroq(opts: {
  model: string
  messages: { role: string; content: string }[]
  max_tokens: number
  stream?: boolean
  json?: boolean
  temperature?: number
}) {
  const key = Deno.env.get('GROQ_API_KEY')
  if (!key) throw new Error('GROQ_API_KEY missing')

  const body: Record<string, unknown> = {
    model: opts.model,
    messages: opts.messages,
    max_tokens: opts.max_tokens,
    temperature: opts.temperature ?? 0.4,
    stream: !!opts.stream,
  }
  if (opts.json) {
    body.response_format = { type: 'json_object' }
  }

  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })

  if (!res.ok) {
    const errText = await res.text()
    throw new Error(`Groq error ${res.status}: ${errText}`)
  }
  return res
}

export function fallbackText(mode: string, skillName?: string) {
  const topic = skillName || 'this topic'
  if (mode === 'hint') {
    return `Hint: Break ${topic} into smaller steps. Recall the definition, try a tiny example, then eliminate options that contradict the basics.`
  }
  return `Here's a quick refresher on ${topic}: focus on the core definition, one concrete example, and a common pitfall. Practice with a short quiz next, then review any flashcards from missed questions.`
}
