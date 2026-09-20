import { useEffect, useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { PageHeader, EmptyState } from '../components/ui'

const LIMIT_SECONDS = 10 * 60

export default function InterviewPage() {
  const [questions, setQuestions] = useState([])
  const [idx, setIdx] = useState(0)
  const [selected, setSelected] = useState(null)
  const [answers, setAnswers] = useState([])
  const [left, setLeft] = useState(LIMIT_SECONDS)
  const [result, setResult] = useState(null)
  const [startedAt] = useState(Date.now())

  useEffect(() => {
    supabase.rpc('get_assessment_questions', {
      p_skill_id: null,
      p_difficulty: 3,
      p_limit: 10,
      p_mode: 'interview',
    }).then(({ data }) => setQuestions(data || []))
  }, [])

  useEffect(() => {
    if (result) return undefined
    const id = setInterval(() => {
      setLeft((s) => {
        if (s <= 1) {
          clearInterval(id)
          finish([...answers])
          return 0
        }
        return s - 1
      })
    }, 1000)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [questions.length, result])

  const q = questions[idx]
  const options = useMemo(() => {
    if (!q) return []
    return Array.isArray(q.options) ? q.options : JSON.parse(q.options)
  }, [q])

  async function finish(finalAnswers) {
    if (result) return
    const payload = finalAnswers.length ? finalAnswers : answers
    if (!payload.length) {
      setResult({ score: 0, level: 'Beginner', correct: 0, total: 0, recommendation: 'Time expired with no answers.' })
      return
    }
    const { data, error } = await supabase.rpc('submit_assessment', {
      p_mode: 'interview',
      p_answers: payload,
      p_time_taken: (Date.now() - startedAt) / 1000,
      p_topic: 'interview',
    })
    if (error) alert(error.message)
    else setResult(data)
  }

  function next() {
    if (selected == null || !q) return
    const nextAnswers = [...answers, { question_id: q.id, selected_index: selected, confidence: 3 }]
    setAnswers(nextAnswers)
    if (idx + 1 >= questions.length) finish(nextAnswers)
    else {
      setIdx(idx + 1)
      setSelected(null)
    }
  }

  if (result) {
    return (
      <EmptyState
        title="Interview complete"
        body={`${result.score}/10 · ${result.level}`}
        action={<Link className="btn-primary" to="/dashboard">Dashboard</Link>}
      />
    )
  }

  if (!q) return <p className="text-white/50">Preparing interview set…</p>

  const mm = String(Math.floor(left / 60)).padStart(2, '0')
  const ss = String(left % 60).padStart(2, '0')

  return (
    <div>
      <PageHeader
        title="Interview mode"
        subtitle="Timed mock quiz — same curated bank, no adaptive difficulty."
        action={<span className={`rounded-xl px-3 py-2 font-mono text-lg ${left < 60 ? 'bg-red-500/20 text-red-200' : 'bg-white/10'}`}>{mm}:{ss}</span>}
      />
      <motion.div className="panel mx-auto max-w-2xl p-6" key={q.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <p className="text-sm text-white/40">Question {idx + 1}/{questions.length}</p>
        <p className="mt-2 text-lg">{q.stem}</p>
        <div className="mt-5 space-y-2">
          {options.map((opt, i) => (
            <button
              key={i}
              type="button"
              className={`w-full rounded-xl border px-4 py-3 text-left ${selected === i ? 'border-tideBright bg-tideBright/15' : 'border-white/10 bg-white/5'}`}
              onClick={() => setSelected(i)}
            >
              {opt}
            </button>
          ))}
        </div>
        <button type="button" className="btn-primary mt-6" disabled={selected == null} onClick={next}>
          {idx + 1 >= questions.length ? 'Submit' : 'Next'}
        </button>
      </motion.div>
    </div>
  )
}
