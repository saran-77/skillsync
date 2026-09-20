import { useEffect, useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { fetchAiQuiz } from '../lib/quiz'
import { useAuth } from '../context/AuthContext'
import { PageHeader, EmptyState } from '../components/ui'

export default function ChallengePage() {
  const { profile } = useAuth()
  const [done, setDone] = useState(false)
  const [questions, setQuestions] = useState([])
  const [idx, setIdx] = useState(0)
  const [selected, setSelected] = useState(null)
  const [answers, setAnswers] = useState([])
  const [result, setResult] = useState(null)
  const [startedAt] = useState(Date.now())
  const [error, setError] = useState('')

  useEffect(() => {
    async function init() {
      const { data: { user } } = await supabase.auth.getUser()
      const today = new Date().toISOString().slice(0, 10)
      const { data: existing } = await supabase.from('daily_challenges').select('*').eq('user_id', user.id).eq('challenge_date', today).maybeSingle()
      if (existing?.completed) {
        setDone(true)
        setResult({ score: existing.score })
        return
      }
      try {
        const focus = profile?.focus_skill_ids
        const { questions: qs } = await fetchAiQuiz({
          skillIds: Array.isArray(focus) && focus.length ? focus : [],
          count: 5,
          difficulty: 3,
          mode: 'daily',
          roleTitle: profile?.roles?.title || '',
        })
        setQuestions(qs)
      } catch (e) {
        setError(e.message)
      }
    }
    init()
  }, [profile?.focus_skill_ids, profile?.roles?.title])

  const q = questions[idx]
  const options = useMemo(() => {
    if (!q) return []
    return Array.isArray(q.options) ? q.options : JSON.parse(q.options)
  }, [q])

  async function next() {
    if (selected == null || !q) return
    const nextAnswers = [...answers, { question_id: q.id, selected_index: selected, confidence: 3 }]
    setAnswers(nextAnswers)
    if (idx + 1 >= questions.length) {
      const { data, error: err } = await supabase.rpc('complete_daily_challenge', {
        p_answers: nextAnswers,
        p_time_taken: (Date.now() - startedAt) / 1000,
      })
      if (err) return alert(err.message)
      setResult(data)
      setDone(true)
      return
    }
    setIdx(idx + 1)
    setSelected(null)
  }

  if (done && result) {
    return (
      <EmptyState
        title="Daily challenge complete"
        body={`Score ${result.score}/10 — streak updated. Come back tomorrow.`}
        action={<Link className="btn-primary" to="/dashboard">Dashboard</Link>}
      />
    )
  }

  if (error) return <EmptyState title="Challenge unavailable" body={error} />
  if (!q) return <p className="text-white/50">Generating today&apos;s AI challenge…</p>

  return (
    <div>
      <PageHeader title="Daily challenge" subtitle={`${idx + 1} / ${questions.length} · AI-generated`} />
      <motion.div className="panel mx-auto max-w-2xl p-6" key={q.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}>
        <p className="text-lg">{q.stem}</p>
        <div className="mt-5 space-y-2">
          {options.map((opt, i) => (
            <button
              key={i}
              type="button"
              className={`w-full rounded-xl border px-4 py-3 text-left ${selected === i ? 'border-sand bg-sand/15' : 'border-white/10 bg-white/5'}`}
              onClick={() => setSelected(i)}
            >
              {opt}
            </button>
          ))}
        </div>
        <button type="button" className="btn-primary mt-6" disabled={selected == null} onClick={next}>
          {idx + 1 >= questions.length ? 'Finish' : 'Next'}
        </button>
      </motion.div>
    </div>
  )
}
