import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AnimatePresence, motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { fetchAiQuiz } from '../lib/quiz'
import { useAuth } from '../context/AuthContext'

const LEARNER_TYPES = [
  { id: 'student', title: 'Student', body: 'Learning for school, bootcamp, or a degree program.' },
  { id: 'career_switcher', title: 'Career switcher', body: 'Moving into a new field and need a clear path.' },
  { id: 'working_pro', title: 'Working professional', body: 'Upskilling on the job with limited time.' },
  { id: 'hobbyist', title: 'Hobbyist', body: 'Building skills for side projects and curiosity.' },
]

const LEVELS = [
  { id: 'beginner', title: 'Beginner', body: 'Just getting started — fundamentals first.' },
  { id: 'intermediate', title: 'Intermediate', body: 'I know the basics and can build simple projects.' },
  { id: 'advanced', title: 'Advanced', body: 'I ship real work and want to close remaining gaps.' },
  { id: 'pro', title: 'Pro', body: 'Strong in this domain — challenge me and target weak spots.' },
]

const slideMotion = {
  initial: { opacity: 0, x: 24 },
  animate: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: -24 },
  transition: { duration: 0.28 },
}

export default function OnboardingPage() {
  const { profile, refreshProfile } = useAuth()
  const navigate = useNavigate()
  const [step, setStep] = useState(1)
  const [roles, setRoles] = useState([])
  const [roleSkills, setRoleSkills] = useState([])
  const [fullName, setFullName] = useState(profile?.full_name || '')
  const [goal, setGoal] = useState('')
  const [learnerType, setLearnerType] = useState('')
  const [roleId, setRoleId] = useState('')
  const [focusSkills, setFocusSkills] = useState([])
  const [level, setLevel] = useState('beginner')
  const [quiz, setQuiz] = useState([])
  const [answers, setAnswers] = useState({})
  const [quizIdx, setQuizIdx] = useState(0)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [result, setResult] = useState(null)

  useEffect(() => {
    if (profile?.full_name) setFullName(profile.full_name)
  }, [profile?.full_name])

  useEffect(() => {
    supabase.from('roles').select('*').order('title').then(({ data }) => setRoles(data || []))
  }, [])

  useEffect(() => {
    if (!roleId) {
      setRoleSkills([])
      setFocusSkills([])
      return
    }
    supabase
      .from('role_skills')
      .select('skill_id, required_level, importance, skills(id, name)')
      .eq('role_id', roleId)
      .order('importance', { ascending: false })
      .then(({ data }) => {
        const rows = data || []
        setRoleSkills(rows)
        setFocusSkills(rows.slice(0, Math.min(4, rows.length)).map((r) => r.skill_id))
      })
  }, [roleId])

  const q = quiz[quizIdx]
  const options = useMemo(() => {
    if (!q) return []
    return Array.isArray(q.options) ? q.options : JSON.parse(q.options)
  }, [q])

  function toggleSkill(id) {
    setFocusSkills((prev) => {
      if (prev.includes(id)) return prev.filter((x) => x !== id)
      if (prev.length >= 6) return prev
      return [...prev, id]
    })
  }

  function validateStep() {
    if (step === 1) {
      if (!fullName.trim()) return 'Enter your name'
    }
    if (step === 2 && !learnerType) return 'Pick how you learn'
    if (step === 3) {
      if (!roleId) return 'Pick a target role'
      if (!focusSkills.length) return 'Select at least one focus skill'
    }
    if (step === 4 && !level) return 'Pick your experience level'
    return ''
  }

  async function next() {
    const err = validateStep()
    if (err) return setError(err)
    setError('')

    if (step === 4) {
      setBusy(true)
      try {
        const { data: { user } } = await supabase.auth.getUser()
        await supabase.from('profiles').update({
          full_name: fullName.trim(),
          learning_goal: goal.trim(),
          learner_type: learnerType,
          target_role_id: roleId,
          experience_level: level,
          focus_skill_ids: focusSkills,
          updated_at: new Date().toISOString(),
        }).eq('id', user.id)

        const levelMap = { beginner: 2, intermediate: 3, advanced: 4, pro: 5 }
        const role = roles.find((r) => r.id === roleId)
        const data = await fetchAiQuiz({
          skillIds: focusSkills,
          count: 5,
          difficulty: levelMap[level] || 3,
          mode: 'onboarding',
          roleTitle: role?.title || '',
        })
        setQuiz(data.questions || [])
        setAnswers({})
        setQuizIdx(0)
        setStep(5)
      } catch (e) {
        setError(e.message || 'Could not load placement quiz')
      } finally {
        setBusy(false)
      }
      return
    }

    setStep((s) => Math.min(5, s + 1))
  }

  async function finishQuiz() {
    if (!quiz.length) return
    const payloadAnswers = quiz.map((item) => ({
      question_id: item.id,
      selected_index: answers[item.id],
      confidence: 3,
    }))
    if (payloadAnswers.some((a) => a.selected_index == null)) {
      return setError('Answer every question before finishing')
    }
    setBusy(true)
    setError('')
    const { data, error: err } = await supabase.rpc('complete_onboarding', {
      p_payload: {
        full_name: fullName.trim(),
        learning_goal: goal.trim(),
        learner_type: learnerType,
        target_role_id: roleId,
        experience_level: level,
        focus_skill_ids: focusSkills,
        answers: payloadAnswers,
      },
    })
    setBusy(false)
    if (err) return setError(err.message)
    setResult(data)
    await refreshProfile()
  }

  if (result) {
    return (
      <div className="mx-auto flex min-h-screen max-w-lg flex-col justify-center px-4 py-12">
        <motion.div className="panel p-8 text-center" initial={{ opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1 }}>
          <p className="text-xs uppercase tracking-[0.2em] text-sand">You&apos;re set</p>
          <h1 className="font-display mt-2 text-3xl font-bold">Placement {Math.round(result.score)}%</h1>
          <p className="mt-3 text-sm text-white/60">{result.recommendation}</p>
          <p className="mt-2 text-sm text-tideBright">
            {result.item_count || 0} modules ready on your path
          </p>
          <button type="button" className="btn-primary mt-8 w-full" onClick={() => navigate('/dashboard')}>
            Open dashboard
          </button>
        </motion.div>
      </div>
    )
  }

  return (
    <div className="mx-auto flex min-h-screen max-w-2xl flex-col px-4 py-10">
      <div className="mb-8">
        <p className="text-xs uppercase tracking-[0.2em] text-sand">Welcome to SkillSync</p>
        <h1 className="font-display mt-2 text-3xl font-bold md:text-4xl">Personalize your path</h1>
        <p className="mt-2 text-sm text-white/55">Five quick steps — then a short placement quiz builds your plan.</p>
        <div className="mt-5 flex gap-2">
          {[1, 2, 3, 4, 5].map((n) => (
            <div
              key={n}
              className={`h-1.5 flex-1 rounded-full ${n <= step ? 'bg-tideBright' : 'bg-white/10'}`}
            />
          ))}
        </div>
      </div>

      {error && <p className="mb-4 text-sm text-red-200">{error}</p>}

      <AnimatePresence mode="wait">
        {step === 1 && (
          <motion.div key="s1" className="panel space-y-4 p-6" {...slideMotion}>
            <h2 className="font-display text-xl font-semibold">About you</h2>
            <div>
              <label className="label">Full name</label>
              <input className="input" value={fullName} onChange={(e) => setFullName(e.target.value)} placeholder="Your name" />
            </div>
            <div>
              <label className="label">Learning goal (optional)</label>
              <textarea
                className="input min-h-[88px]"
                value={goal}
                onChange={(e) => setGoal(e.target.value)}
                placeholder="e.g. Land a frontend internship in 3 months"
              />
            </div>
          </motion.div>
        )}

        {step === 2 && (
          <motion.div key="s2" className="panel space-y-3 p-6" {...slideMotion}>
            <h2 className="font-display text-xl font-semibold">What describes you best?</h2>
            {LEARNER_TYPES.map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => setLearnerType(t.id)}
                className={`w-full rounded-xl border p-4 text-left transition ${
                  learnerType === t.id ? 'border-tideBright bg-tideBright/10' : 'border-white/10 bg-white/5 hover:border-white/25'
                }`}
              >
                <div className="font-display font-semibold">{t.title}</div>
                <p className="mt-1 text-sm text-white/55">{t.body}</p>
              </button>
            ))}
          </motion.div>
        )}

        {step === 3 && (
          <motion.div key="s3" className="panel space-y-4 p-6" {...slideMotion}>
            <h2 className="font-display text-xl font-semibold">Role & focus skills</h2>
            <div className="grid gap-2">
              {roles.map((r) => (
                <button
                  key={r.id}
                  type="button"
                  onClick={() => setRoleId(r.id)}
                  className={`rounded-xl border p-3 text-left transition ${
                    roleId === r.id ? 'border-tideBright bg-tideBright/10' : 'border-white/10 bg-white/5 hover:border-white/25'
                  }`}
                >
                  <div className="font-medium">{r.title}</div>
                  <p className="mt-0.5 text-xs text-white/45">{r.description}</p>
                </button>
              ))}
            </div>
            {roleSkills.length > 0 && (
              <div>
                <p className="label">Skills to master (pick 1–6)</p>
                <div className="mt-2 flex flex-wrap gap-2">
                  {roleSkills.map((rs) => {
                    const on = focusSkills.includes(rs.skill_id)
                    return (
                      <button
                        key={rs.skill_id}
                        type="button"
                        onClick={() => toggleSkill(rs.skill_id)}
                        className={`rounded-lg px-3 py-1.5 text-sm ${
                          on ? 'bg-sand/20 text-sand' : 'bg-white/5 text-white/60 hover:bg-white/10'
                        }`}
                      >
                        {rs.skills?.name}
                      </button>
                    )
                  })}
                </div>
              </div>
            )}
          </motion.div>
        )}

        {step === 4 && (
          <motion.div key="s4" className="panel space-y-3 p-6" {...slideMotion}>
            <h2 className="font-display text-xl font-semibold">Experience level</h2>
            <p className="text-sm text-white/50">We use this to pitch the placement quiz and starting path difficulty.</p>
            {LEVELS.map((lv) => (
              <button
                key={lv.id}
                type="button"
                onClick={() => setLevel(lv.id)}
                className={`w-full rounded-xl border p-4 text-left transition ${
                  level === lv.id ? 'border-sand bg-sand/10' : 'border-white/10 bg-white/5 hover:border-white/25'
                }`}
              >
                <div className="font-display font-semibold">{lv.title}</div>
                <p className="mt-1 text-sm text-white/55">{lv.body}</p>
              </button>
            ))}
          </motion.div>
        )}

        {step === 5 && (
          <motion.div key="s5" className="panel space-y-4 p-6" {...slideMotion}>
            <div className="flex items-center justify-between gap-3">
              <h2 className="font-display text-xl font-semibold">Placement quiz</h2>
              <span className="text-sm text-white/40">{quizIdx + 1}/{quiz.length || 5}</span>
            </div>
            {!quiz.length ? (
              <p className="text-sm text-white/50">Preparing questions for your level…</p>
            ) : (
              <>
                <p className="text-lg">{q?.stem}</p>
                <div className="space-y-2">
                  {options.map((opt, i) => (
                    <button
                      key={i}
                      type="button"
                      onClick={() => setAnswers((prev) => ({ ...prev, [q.id]: i }))}
                      className={`w-full rounded-xl border px-4 py-3 text-left ${
                        answers[q.id] === i ? 'border-tideBright bg-tideBright/15' : 'border-white/10 bg-white/5'
                      }`}
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              </>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      <div className="mt-6 flex flex-wrap gap-3">
        {step > 1 && step < 5 && (
          <button type="button" className="btn-ghost" disabled={busy} onClick={() => { setError(''); setStep((s) => s - 1) }}>
            Back
          </button>
        )}
        {step < 4 && (
          <button type="button" className="btn-primary ml-auto" disabled={busy} onClick={next}>
            Continue
          </button>
        )}
        {step === 4 && (
          <button type="button" className="btn-primary ml-auto" disabled={busy} onClick={next}>
            {busy ? 'Building quiz…' : 'Start placement quiz'}
          </button>
        )}
        {step === 5 && quiz.length > 0 && (
          <>
            {quizIdx > 0 && (
              <button type="button" className="btn-ghost" disabled={busy} onClick={() => setQuizIdx((i) => i - 1)}>
                Previous
              </button>
            )}
            {quizIdx + 1 < quiz.length ? (
              <button
                type="button"
                className="btn-primary ml-auto"
                disabled={busy || answers[q?.id] == null}
                onClick={() => setQuizIdx((i) => i + 1)}
              >
                Next question
              </button>
            ) : (
              <button type="button" className="btn-primary ml-auto" disabled={busy} onClick={finishQuiz}>
                {busy ? 'Saving path…' : 'Finish & build my path'}
              </button>
            )}
          </>
        )}
      </div>
    </div>
  )
}
