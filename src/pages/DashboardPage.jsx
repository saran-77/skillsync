import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import {
  Radar, RadarChart, PolarGrid, PolarAngleAxis, ResponsiveContainer,
  BarChart, Bar, XAxis, YAxis, Tooltip,
} from 'recharts'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import { PageHeader, Skeleton } from '../components/ui'

export default function DashboardPage() {
  const { profile } = useAuth()
  const [skills, setSkills] = useState([])
  const [history, setHistory] = useState([])
  const [challenge, setChallenge] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    async function load() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const [{ data: us }, { data: assessments }, { data: daily }] = await Promise.all([
        supabase.from('user_skills').select('proficiency, skills(name)').eq('user_id', user.id),
        supabase.from('assessments').select('id, score, level, mode, completed_at').eq('user_id', user.id).order('completed_at', { ascending: false }).limit(8),
        supabase.from('daily_challenges').select('*').eq('user_id', user.id).eq('challenge_date', new Date().toISOString().slice(0, 10)).maybeSingle(),
      ])
      if (cancelled) return
      setSkills((us || []).map((r) => ({ skill: r.skills?.name || 'Skill', value: Number(r.proficiency) * 10 })))
      setHistory(assessments || [])
      setChallenge(daily)
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading) return <Skeleton className="h-80" />

  return (
    <div>
      <PageHeader
        title={`Hey ${profile?.full_name || 'learner'}`}
        subtitle={`Target: ${profile?.roles?.title || 'not set'} · Streak ${profile?.streak_count || 0} · ${profile?.xp || 0} XP`}
        action={
          <Link to="/assessment" className="btn-primary">Take assessment</Link>
        }
      />

      {!challenge?.completed && (
        <motion.div
          className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-sand/30 bg-sand/10 px-5 py-4"
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <div>
            <p className="font-display font-semibold text-sand">Daily challenge ready</p>
            <p className="text-sm text-white/60">Five quick questions — keep your streak alive.</p>
          </div>
          <Link to="/challenge" className="btn-ghost">Start</Link>
        </motion.div>
      )}

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="panel p-5 lg:col-span-2">
          <h3 className="font-display text-lg font-semibold">Skill radar</h3>
          <div className="mt-4 h-72">
            {skills.length ? (
              <ResponsiveContainer width="100%" height="100%">
                <RadarChart data={skills}>
                  <PolarGrid stroke="#ffffff22" />
                  <PolarAngleAxis dataKey="skill" tick={{ fill: '#e8eef8aa', fontSize: 11 }} />
                  <Radar dataKey="value" stroke="#2a9d8f" fill="#2a9d8f" fillOpacity={0.3} />
                </RadarChart>
              </ResponsiveContainer>
            ) : (
              <p className="flex h-full items-center justify-center text-white/45">Complete an assessment to see skills.</p>
            )}
          </div>
        </div>
        <div className="panel p-5">
          <h3 className="font-display text-lg font-semibold">Quick links</h3>
          <div className="mt-4 grid gap-2">
            {[
              ['/gaps', 'View skill gaps'],
              ['/path', 'Learning path'],
              ['/tutor', 'Ask the tutor'],
              ['/flashcards', 'Review flashcards'],
              ['/interview', 'Interview mode'],
            ].map(([to, label]) => (
              <Link key={to} to={to} className="rounded-xl bg-white/5 px-3 py-2.5 text-sm hover:bg-white/10">{label}</Link>
            ))}
          </div>
        </div>
        <div className="panel p-5 lg:col-span-3">
          <h3 className="font-display text-lg font-semibold">Proficiency bars</h3>
          <div className="mt-4 h-64">
            {skills.length ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={skills}>
                  <XAxis dataKey="skill" stroke="#ffffff66" tick={{ fontSize: 11 }} />
                  <YAxis stroke="#ffffff66" domain={[0, 100]} />
                  <Tooltip contentStyle={{ background: '#1e2a44', border: '1px solid #ffffff22' }} />
                  <Bar dataKey="value" fill="#f0a05a" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <p className="text-white/45">No skill data yet.</p>
            )}
          </div>
        </div>
        <div className="panel p-5 lg:col-span-3">
          <h3 className="font-display text-lg font-semibold">Recent assessments</h3>
          <div className="mt-4 divide-y divide-white/10">
            {history.length === 0 && <p className="text-white/45">No assessments yet.</p>}
            {history.map((a) => (
              <div key={a.id} className="flex items-center justify-between py-3 text-sm">
                <span className="capitalize text-white/70">{a.mode}</span>
                <span>{a.score}/10 · {a.level}</span>
                <span className="text-white/40">{a.completed_at ? new Date(a.completed_at).toLocaleDateString() : '—'}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
