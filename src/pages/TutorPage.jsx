import { useEffect, useRef, useState } from 'react'
import { motion } from 'framer-motion'
import { supabase, invokeFunction } from '../lib/supabase'
import { PageHeader } from '../components/ui'

export default function TutorPage() {
  const [skills, setSkills] = useState([])
  const [skillId, setSkillId] = useState('')
  const [sessionId, setSessionId] = useState(null)
  const [messages, setMessages] = useState([])
  const [input, setInput] = useState('')
  const [busy, setBusy] = useState(false)
  const [quotaMsg, setQuotaMsg] = useState('')
  const bottomRef = useRef(null)

  useEffect(() => {
    supabase.from('skills').select('id, name').order('name').then(({ data }) => setSkills(data || []))
  }, [])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  async function send(e) {
    e?.preventDefault()
    if (!input.trim() || busy) return
    const text = input.trim()
    setInput('')
    setMessages((m) => [...m, { role: 'user', content: text }])
    setBusy(true)
    setQuotaMsg('')

    try {
      const res = await invokeFunction('ai-tutor', {
        message: text,
        skill_id: skillId || undefined,
        session_id: sessionId || undefined,
        mode: 'chat',
        stream: true,
      }, { stream: true })

      if (res instanceof Response && res.headers.get('content-type')?.includes('text/event-stream')) {
        const reader = res.body.getReader()
        const decoder = new TextDecoder()
        let assistant = ''
        setMessages((m) => [...m, { role: 'assistant', content: '' }])
        let buffer = ''
        while (true) {
          const { done, value } = await reader.read()
          if (done) break
          buffer += decoder.decode(value, { stream: true })
          const chunks = buffer.split('\n')
          buffer = chunks.pop() || ''
          for (const line of chunks) {
            if (!line.startsWith('data:')) continue
            const payload = line.slice(5).trim()
            if (!payload) continue
            try {
              const json = JSON.parse(payload)
              if (json.session_id) setSessionId(json.session_id)
              if (json.delta) {
                assistant += json.delta
                setMessages((m) => {
                  const copy = [...m]
                  copy[copy.length - 1] = { role: 'assistant', content: assistant, source: 'groq' }
                  return copy
                })
              }
              if (json.done && json.text) {
                assistant = json.text
                setMessages((m) => {
                  const copy = [...m]
                  copy[copy.length - 1] = { role: 'assistant', content: assistant, source: json.source }
                  return copy
                })
              }
            } catch { /* ignore */ }
          }
        }
      } else {
        const json = res
        if (json.session_id) setSessionId(json.session_id)
        setMessages((m) => [...m, { role: 'assistant', content: json.text, source: json.source }])
        if (json.reason === 'rate_limit') setQuotaMsg('Daily AI budget reached — showing fallback tips.')
      }
    } catch (err) {
      if (err.status === 429) {
        setQuotaMsg('Daily AI budget reached — showing fallback tips.')
        setMessages((m) => [...m, { role: 'assistant', content: err.payload?.text || 'Try reviewing flashcards while the quota resets.', source: 'fallback' }])
      } else {
        setMessages((m) => [...m, { role: 'assistant', content: err.message || 'Tutor unavailable.', source: 'fallback' }])
      }
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="mx-auto flex max-w-3xl flex-col" style={{ minHeight: '70vh' }}>
      <PageHeader
        title="AI tutor"
        subtitle="Messages go to Groq. Don’t paste secrets. Cap: 30 requests/day."
      />
      {quotaMsg && <p className="mb-3 rounded-xl bg-sand/15 px-3 py-2 text-sm text-sand">{quotaMsg}</p>}
      <div className="mb-3">
        <label className="label">Focus skill (optional)</label>
        <select className="input" value={skillId} onChange={(e) => setSkillId(e.target.value)}>
          <option value="">General</option>
          {skills.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
      </div>
      <div className="panel flex flex-1 flex-col overflow-hidden">
        <div className="flex-1 space-y-3 overflow-y-auto p-4">
          {messages.length === 0 && (
            <p className="text-sm text-white/45">Ask for an explanation, a worked example, or a study plan tip.</p>
          )}
          {messages.map((m, i) => (
            <motion.div
              key={i}
              className={`max-w-[90%] rounded-2xl px-4 py-3 text-sm ${
                m.role === 'user' ? 'ml-auto bg-tideBright/20' : 'bg-white/5'
              }`}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
            >
              {m.content}
              {m.source && m.role === 'assistant' && (
                <span className="mt-1 block text-[10px] uppercase tracking-wide text-white/35">{m.source}</span>
              )}
            </motion.div>
          ))}
          <div ref={bottomRef} />
        </div>
        <form onSubmit={send} className="flex gap-2 border-t border-white/10 p-3">
          <input
            className="input"
            placeholder="Ask anything about your path…"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            disabled={busy}
          />
          <button className="btn-primary" disabled={busy || !input.trim()}>{busy ? '…' : 'Send'}</button>
        </form>
      </div>
    </div>
  )
}
