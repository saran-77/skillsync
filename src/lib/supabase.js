import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !anon) {
  console.warn('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY')
}

export const supabase = createClient(url || 'http://127.0.0.1:54321', anon || 'public-anon-key')

export async function invokeFunction(name, body, { stream = false } = {}) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) throw new Error('Not signed in')

  const res = await fetch(`${url}/functions/v1/${name}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${session.access_token}`,
      apikey: anon,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })

  if (stream && res.ok && res.headers.get('content-type')?.includes('text/event-stream')) {
    return res
  }

  const json = await res.json().catch(() => ({}))
  if (!res.ok) {
    const err = new Error(json.error || json.message || 'Request failed')
    err.status = res.status
    err.payload = json
    throw err
  }
  return json
}
