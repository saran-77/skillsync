import { useEffect, useMemo, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { Link } from 'react-router-dom'
import { supabase, invokeFunction } from '../lib/supabase'
import { fetchAiQuiz } from '../lib/quiz'
import { useAuth } from '../context/AuthContext'
import { PageHeader, Chip } from '../components/ui'
import { scaleIn } from '../lib/motion'

export default function AssessmentPage() {
  const { profile } = useAuth()
  const [difficulty, setDifficulty] = useState(3)
  const [question, setQuestion] = useState(null)
  const [answers, setAnswers] = useState([])
  const [selected, setSelected] = useState(null)
  const [confidence, setConfidence] = useState(3)
  const [step, setStep] = useState(0)
  const [startedAt] = useState(Date.now())
  const [result, setResult] = useState(null)
  const [busy, setBusy] = useState(false)
  const [hint, setHint] = useState('')
  const total = 8

  const skillIds = useMemo(() => {
    const focus = profile?.focus_skill_ids
    return Array.isArray(focus) && focus.length ? focus : []
  }, [profile?.focus_skill_ids])

  async function loadQuestion(diff, excludeIds) {
    setBusy(true)
    setSelected(null)
    setHint('')
    const exclude = excludeIds ?? answers.map((a) => a.question_id)
    try {
      const { questions } = await fetchAiQuiz({
        skillIds,
        count: 1,
        difficulty: diff,
        mode: 'adaptive',
        excludeIds: exclude,
        roleTitle: profile?.roles?.title || '',
      })
      setQuestion(questions[0] || null)
    } catch (e) {
      console.error(e)
      setQuestion(null)
    } finally {
      setBusy(false)
    }
  }

  useEffect(() => {
    async function boot() {
      const { data: nextDiff } = await supabase.rpc('get_next_difficulty', { p_skill_id: null })
      const d = nextDiff || 3
      setDifficulty(d)
      await loadQuestion(d)
    }
    boot()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const options = useMemo(() => {
    if (!question) return []
    return Array.isArray(question.options) ? question.options : JSON.parse(question.options)
  }, [question])

  async function next() {
    if (selected == null || !question) return
    const nextAnswers = [...answers, {
      question_id: question.id,
      selected_index: selected,
      confidence,
    }]
    setAnswers(nextAnswers)

    if (step + 1 >= total) {
      setBusy(true)
      const { data, error } = await supabase.rpc('submit_assessment', {
        p_mode: 'adaptive',
        p_answers: nextAnswers,
        p_time_taken: (Date.now() - startedAt) / 1000,
        p_topic: 'adaptive',
      })
      setBusy(false)
      if (error) return alert(error.message)
      setResult(data)
      return
    }

    const { data: nextDiff } = await supabase.rpc('get_next_difficulty', {
      p_skill_id: question.skill_id || null,
    })
    let d = nextDiff || difficulty
    if (confidence >= 5) d = Math.min(5, d + 1)
    if (confidence <= 1) d = Math.max(1, d - 1)
    setDifficulty(d)
    setStep(step + 1)
    await loadQuestion(d, nextAnswers.map((a) => a.question_id))
  }

  async function askHint() {
    if (!question) return
    try {
      const res = await invokeFunction('ai-tutor', {
        mode: 'hint',
        skill_id: question.skill_id,
        message: `Give a short hint for this question without revealing the answer: ${question.stem}`,
        stream: false,
      })
      setHint(res.text)
    } catch (e) {
      setHint(e.payload?.text || 'Think about the core definition, then eliminate extremes.')
    }
  }

  if (result) {
    return (
      <motion.div className="panel mx-auto max-w-xl p-8 text-center" {...scaleIn}>
        <h2 className="font-display text-3xl font-bold">Assessment complete</h2>
        <p className="mt-4 text-5xl font-extrabold text-tideBright">{result.score}<span className="text-lg text-white/50">/10</span></p>
        <p className="mt-2 text-white/60">{result.level} · {result.correct}/{result.total} correct</p>
        <p className="mt-4 text-sm text-white/55">{result.recommendation}</p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link className="btn-primary" to="/dna">View Skill DNA</Link>
          <Link className="btn-ghost" to="/gaps">See gaps</Link>
          <Link className="btn-ghost" to="/path">Build path</Link>
          <Link className="btn-ghost" to="/flashcards">Review misses</Link>
        </div>
      </motion.div>
    )
  }

  return (
    <div>
      <PageHeader
        title="Adaptive assessment"
        subtitle="Fresh AI questions each step — difficulty adjusts as you answer."
        action={<Chip tone="sand">Q {step + 1}/{total} · d{difficulty}</Chip>}
      />
      <AnimatePresence mode="wait">
        {question ? (
          <motion.div
            key={question.id}
            className="panel mx-auto max-w-2xl p-6"
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
          >
            <p className="text-lg">{question.stem}</p>
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
            <div className="mt-5">
              <label className="label">Confidence {confidence}/5</label>
              <input
                type="range"
                min={1}
                max={5}
                value={confidence}
                onChange={(e) => setConfidence(Number(e.target.value))}
                className="w-full accent-tideBright"
              />
            </div>
            <div className="mt-6 flex flex-wrap gap-3">
              <button type="button" className="btn-ghost" onClick={askHint}>Hint</button>
              <button type="button" className="btn-primary ml-auto" disabled={selected == null || busy} onClick={next}>
                {busy ? 'Loading…' : step + 1 >= total ? 'Submit' : 'Next'}
              </button>
            </div>
            {hint && <p className="mt-4 text-sm text-white/55">{hint}</p>}
          </motion.div>
        ) : (
          <p className="text-center text-white/50">{busy ? 'Generating AI question…' : 'No question available. Try again.'}</p>
        )}
      </AnimatePresence>
    </div>
  )
}
