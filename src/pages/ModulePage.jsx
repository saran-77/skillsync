import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { AnimatePresence, motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { fetchAiQuiz } from '../lib/quiz'
import { PageHeader, EmptyState, Skeleton, Chip } from '../components/ui'
import { fadeUp, scaleIn } from '../lib/motion'

export default function ModulePage() {
  const { itemId } = useParams()
  const navigate = useNavigate()
  const [item, setItem] = useState(null)
  const [lessons, setLessons] = useState([])
  const [resources, setResources] = useState([])
  const [tab, setTab] = useState('study')
  const [ready, setReady] = useState(false)
  const [quiz, setQuiz] = useState(null)
  const [answers, setAnswers] = useState({})
  const [result, setResult] = useState(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    setError('')
    const { data: row, error: err } = await supabase
      .from('path_items')
      .select('*, skills(id, name)')
      .eq('id', itemId)
      .maybeSingle()
    if (err || !row) {
      setError(err?.message || 'Module not found')
      setLoading(false)
      return
    }
    if (row.status === 'locked') {
      setError('This module is locked. Pass the previous quiz first.')
      setItem(row)
      setLoading(false)
      return
    }

    await supabase.rpc('start_path_module', { p_item_id: itemId })

    const [{ data: lessonRows }, { data: resRows }] = await Promise.all([
      supabase.from('skill_lessons').select('*').eq('skill_id', row.skill_id).order('sort_order'),
      supabase.from('resources').select('*').eq('skill_id', row.skill_id).order('difficulty'),
    ])
    setItem(row)
    setLessons(lessonRows || [])
    setResources(resRows || [])
    setLoading(false)
  }, [itemId])

  useEffect(() => { load() }, [load])

  async function loadQuiz() {
    setBusy(true)
    setResult(null)
    setError('')
    try {
      const level = 3
      const { questions } = await fetchAiQuiz({
        skillIds: item?.skill_id ? [item.skill_id] : [],
        count: 5,
        difficulty: level,
        mode: 'module',
        topicHint: item?.skills?.name || '',
      })
      if (!questions.length) throw new Error('Could not generate module quiz')
      setQuiz({ questions, pass_percent: 70, skill_name: item?.skills?.name })
      setAnswers({})
      setTab('quiz')
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(false)
    }
  }

  async function submitQuiz() {
    if (!quiz?.questions?.length) return
    const payload = quiz.questions.map((q) => ({
      question_id: q.id,
      selected_index: answers[q.id],
      confidence: 3,
    }))
    if (payload.some((p) => p.selected_index == null)) {
      return setError('Answer every question before submitting.')
    }
    setBusy(true)
    setError('')
    const { data, error: err } = await supabase.rpc('submit_module_quiz', {
      p_item_id: itemId,
      p_answers: payload,
    })
    setBusy(false)
    if (err) return setError(err.message)
    setResult(data)
  }

  const progressLabel = useMemo(() => {
    if (!item) return ''
    if (item.status === 'completed') return 'Passed'
    return item.attempts ? `${item.attempts} attempt(s)` : 'Not passed yet'
  }, [item])

  if (loading) return <Skeleton className="h-80" />

  if (error && !item) {
    return <EmptyState title="Unavailable" body={error} action={<Link className="btn-primary" to="/path">Back to path</Link>} />
  }

  if (item?.status === 'locked') {
    return <EmptyState title="Module locked" body={error || 'Pass the previous module quiz to unlock this one.'} action={<Link className="btn-primary" to="/path">Back to path</Link>} />
  }

  if (result) {
    return (
      <motion.div className="panel mx-auto max-w-2xl p-8 text-center" {...scaleIn}>
        <h2 className="font-display text-3xl font-bold">{result.passed ? 'Module passed' : 'Not yet — keep studying'}</h2>
        <p className="mt-4 text-5xl font-extrabold text-tideBright">{Math.round(result.score)}%</p>
        <p className="mt-2 text-white/60">{result.correct}/{result.total} correct · need {result.pass_percent}%</p>

        {result.misses?.length > 0 && (
          <div className="mt-6 space-y-3 text-left">
            <h3 className="font-display text-lg font-semibold">Review misses</h3>
            {result.misses.map((m) => (
              <div key={m.question_id} className="rounded-xl bg-ink/50 p-3 text-sm">
                <p className="text-white/80">{m.stem}</p>
                <p className="mt-2 text-sand">{m.explanation}</p>
              </div>
            ))}
          </div>
        )}

        <div className="mt-8 flex flex-wrap justify-center gap-3">
          {result.passed ? (
            <>
              {result.next_item_id ? (
                <button type="button" className="btn-primary" onClick={() => navigate(`/path/${result.next_item_id}`)}>Next module</button>
              ) : (
                <Link className="btn-primary" to="/path">Path complete</Link>
              )}
              <Link className="btn-ghost" to="/dashboard">Dashboard</Link>
            </>
          ) : (
            <>
              <button type="button" className="btn-primary" onClick={() => { setResult(null); setTab('study'); setReady(false) }}>Back to study</button>
              <button type="button" className="btn-ghost" onClick={() => { setResult(null); loadQuiz() }}>Retry quiz</button>
            </>
          )}
        </div>
      </motion.div>
    )
  }

  return (
    <div>
      <PageHeader
        title={item?.skills?.name || 'Module'}
        subtitle={`Study the lessons, then pass the scenario quiz (70%). ${progressLabel}.`}
        action={<Link className="btn-ghost" to="/path">All modules</Link>}
      />

      {error && <p className="mb-4 rounded-xl bg-red-500/15 px-3 py-2 text-sm text-red-200">{error}</p>}

      <div className="mb-6 flex gap-2 rounded-xl bg-white/5 p-1 w-fit">
        <button type="button" className={`rounded-lg px-4 py-2 text-sm ${tab === 'study' ? 'bg-white/10' : 'text-white/50'}`} onClick={() => setTab('study')}>Study</button>
        <button
          type="button"
          className={`rounded-lg px-4 py-2 text-sm ${tab === 'quiz' ? 'bg-white/10' : 'text-white/50'}`}
          onClick={() => (ready || quiz ? (quiz ? setTab('quiz') : loadQuiz()) : null)}
          disabled={!ready && !quiz}
        >
          Quiz {!ready && !quiz ? '(unlock after ready)' : ''}
        </button>
      </div>

      <AnimatePresence mode="wait">
        {tab === 'study' ? (
          <motion.div key="study" className="space-y-4" {...fadeUp}>
            {lessons.map((lesson) => (
              <article key={lesson.id} className="panel p-5 md:p-6">
                <div className="mb-3 flex flex-wrap items-center gap-2">
                  <h3 className="font-display text-xl font-semibold">{lesson.title}</h3>
                  <Chip>~{lesson.estimated_minutes} min</Chip>
                </div>
                <div className="prose-study space-y-3 text-sm leading-relaxed text-white/75 whitespace-pre-wrap">
                  {lesson.body_md}
                </div>
              </article>
            ))}

            <div className="panel p-5">
              <h3 className="font-display text-lg font-semibold">Open study materials</h3>
              <ul className="mt-3 space-y-2">
                {resources.map((r) => (
                  <li key={r.id} className="flex flex-wrap items-center gap-2 rounded-xl bg-ink/40 px-3 py-2">
                    <Chip tone="tide">{r.type}</Chip>
                    <a className="text-sm text-tideBright underline" href={r.url} target="_blank" rel="noreferrer">{r.title}</a>
                  </li>
                ))}
                {!resources.length && <li className="text-sm text-white/40">No external links for this skill.</li>}
              </ul>
            </div>

            {item?.status === 'completed' ? (
              <p className="rounded-xl bg-tideBright/10 px-4 py-3 text-sm text-tideBright">You already passed this module. You can still review the lessons below.</p>
            ) : (
              <>
                <label className="panel flex cursor-pointer items-start gap-3 p-4">
                  <input type="checkbox" className="mt-1 accent-tideBright" checked={ready} onChange={(e) => setReady(e.target.checked)} />
                  <span className="text-sm text-white/70">I studied the lessons and I&apos;m ready for the scenario quiz.</span>
                </label>
                <button type="button" className="btn-primary" disabled={!ready || busy} onClick={loadQuiz}>
                  {busy ? 'Loading quiz…' : 'Start module quiz'}
                </button>
              </>
            )}
          </motion.div>
        ) : (
          <motion.div key="quiz" className="space-y-4" {...fadeUp}>
            <p className="text-sm text-white/50">Answer all questions. Pass at {quiz?.pass_percent || 70}% to unlock the next module.</p>
            {(quiz?.questions || []).map((q, qi) => {
              const opts = Array.isArray(q.options) ? q.options : JSON.parse(q.options)
              return (
                <div key={q.id} className="panel p-5">
                  <div className="mb-3 flex flex-wrap gap-2">
                    <Chip>Q{qi + 1}</Chip>
                    <Chip tone="tide">Diff {q.difficulty}</Chip>
                    {q.concept && <Chip tone="sand">{String(q.concept).replace(/-/g, ' ')}</Chip>}
                  </div>
                  <p className="text-base leading-relaxed">{q.stem}</p>
                  <div className="mt-4 space-y-2">
                    {opts.map((opt, idx) => (
                      <button
                        key={idx}
                        type="button"
                        onClick={() => setAnswers((a) => ({ ...a, [q.id]: idx }))}
                        className={`w-full rounded-xl border px-4 py-3 text-left text-sm transition ${
                          answers[q.id] === idx ? 'border-tideBright bg-tideBright/15' : 'border-white/10 bg-white/5 hover:border-white/25'
                        }`}
                      >
                        {opt}
                      </button>
                    ))}
                  </div>
                </div>
              )
            })}
            <button type="button" className="btn-primary" disabled={busy} onClick={submitQuiz}>
              {busy ? 'Scoring…' : 'Submit quiz'}
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
