import { useEffect, useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { fetchAiQuiz } from '../lib/quiz'
import { PageHeader } from '../components/ui'

export default function PracticePage() {
  const [skills, setSkills] = useState([])
  const [skillId, setSkillId] = useState('')
  const [difficulty, setDifficulty] = useState(3)
  const [question, setQuestion] = useState(null)
  const [selected, setSelected] = useState(null)
  const [result, setResult] = useState(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    supabase.from('skills').select('id, name').order('name').then(({ data }) => {
      setSkills(data || [])
      if (data?.[0]) setSkillId(data[0].id)
    })
  }, [])

  const options = useMemo(() => {
    if (!question) return []
    return Array.isArray(question.options) ? question.options : JSON.parse(question.options)
  }, [question])

  async function generate() {
    setBusy(true)
    setError('')
    setResult(null)
    setSelected(null)
    try {
      const { questions } = await fetchAiQuiz({
        skillIds: skillId ? [skillId] : [],
        count: 1,
        difficulty,
        mode: 'adaptive',
        topicHint: 'practice drill',
      })
      setQuestion(questions[0] || null)
      if (!questions[0]) setError('No question generated')
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(false)
    }
  }

  async function submit() {
    if (!question || selected == null) return
    setBusy(true)
    const { data, error: err } = await supabase.rpc('submit_assessment', {
      p_mode: 'practice',
      p_answers: [{ question_id: question.id, selected_index: selected, confidence: 3 }],
      p_time_taken: 0,
      p_topic: 'practice',
    })
    setBusy(false)
    if (err) setError(err.message)
    else setResult(data)
  }

  return (
    <div>
      <PageHeader title="Practice (AI)" subtitle="Each generate call creates a new AI question for the skill you pick." />
      <div className="panel mb-6 grid gap-3 p-4 md:grid-cols-3">
        <div>
          <label className="label">Skill</label>
          <select className="input" value={skillId} onChange={(e) => setSkillId(e.target.value)}>
            {skills.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </div>
        <div>
          <label className="label">Difficulty</label>
          <input className="input" type="number" min={1} max={5} value={difficulty} onChange={(e) => setDifficulty(Number(e.target.value))} />
        </div>
        <div className="flex items-end">
          <button type="button" className="btn-primary w-full" disabled={busy || !skillId} onClick={generate}>
            {busy ? 'Generating…' : 'Generate question'}
          </button>
        </div>
      </div>
      {error && <p className="mb-4 text-sm text-red-200">{error}</p>}
      {question && (
        <motion.div className="panel mx-auto max-w-2xl p-6" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}>
          <p className="text-lg">{question.stem}</p>
          <div className="mt-4 space-y-2">
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
          <button type="button" className="btn-primary mt-6" disabled={selected == null || busy} onClick={submit}>Check</button>
          {result && (
            <p className="mt-4 text-sm text-white/70">
              Score {result.score}/10 · {result.correct}/{result.total} correct
              {question.explanation && <span className="mt-2 block text-white/50">{question.explanation}</span>}
            </p>
          )}
        </motion.div>
      )}
    </div>
  )
}
