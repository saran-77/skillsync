import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import {
  Radar, RadarChart, PolarGrid, PolarAngleAxis, ResponsiveContainer,
  BarChart, Bar, XAxis, YAxis, Tooltip,
} from 'recharts'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import { Skeleton, Chip, StaggerList, StaggerItem } from '../components/ui'
import { fadeUp } from '../lib/motion'

export default function DashboardPage() {
  const { profile } = useAuth()
  const [skills, setSkills] = useState([])
  const [history, setHistory] = useState([])
  const [mission, setMission] = useState(null)
  const [gapStats, setGapStats] = useState({ total: 0, critical: 0 })
  const [chart, setChart] = useState('radar')
  const [moduleProgress, setModuleProgress] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    async function load() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const [
        { data: dna },
        { data: assessments },
        { data: missionData },
        gapsRes,
        { data: modProg },
      ] = await Promise.all([
        supabase.rpc('get_skill_dna'),
        supabase.from('assessments').select('id, score, level, mode, completed_at').eq('user_id', user.id).order('completed_at', { ascending: false }).limit(8),
        supabase.rpc('get_todays_mission'),
        supabase.rpc('compute_gaps'),
        supabase.rpc('get_module_progress'),
      ])
      if (cancelled) return
      const skillRows = dna?.skills || []
      setSkills(skillRows.map((r) => ({ skill: r.skill_name || 'Skill', value: Number(r.mastery_score) || 0 })))
      setHistory(assessments || [])
      setMission(missionData)
      setModuleProgress(modProg)
      const gapList = gapsRes.error ? [] : (gapsRes.data || [])
      setGapStats({
        total: gapList.filter((g) => Number(g.gap) > 0.5).length,
        critical: gapList.filter((g) => g.priority === 'High').length,
      })
      setLoading(false)
    }
    load()
    return () => { cancelled = true }
  }, [])

  if (loading) return <Skeleton className="h-80" />

  return (
    <div className="space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <motion.h1 className="font-display text-3xl font-bold md:text-4xl" {...fadeUp}>
            {profile?.full_name || 'Learner'}
          </motion.h1>
          <div className="mt-3 flex flex-wrap gap-2">
            <Chip tone="tide">{profile?.roles?.title || 'No role set'}</Chip>
            <Chip>{profile?.xp ?? 0} XP</Chip>
            <Chip tone="sand">{profile?.streak_count ?? 0}-day streak</Chip>
          </div>
        </div>
        <Link to="/dna" className="btn-primary">Open Skill DNA</Link>
      </div>

      {moduleProgress?.has_path && (
        <motion.section className="panel p-5" {...fadeUp}>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p className="text-xs uppercase tracking-[0.18em] text-sand">Path progress</p>
              <h2 className="font-display mt-1 text-2xl font-bold">
                {moduleProgress.completed}/{moduleProgress.total} modules passed
              </h2>
              {moduleProgress.current ? (
                <p className="mt-2 text-sm text-white/55">
                  Continue: <span className="text-mist">{moduleProgress.current.skill_name}</span>
                  {moduleProgress.current.attempts ? ` · ${moduleProgress.current.attempts} attempt(s)` : ''}
                  {moduleProgress.current.best_score != null ? ` · best ${Math.round(moduleProgress.current.best_score)}%` : ''}
                </p>
              ) : (
                <p className="mt-2 text-sm text-tideBright">All modules completed for this path.</p>
              )}
            </div>
            {moduleProgress.current ? (
              <Link className="btn-primary" to={`/path/${moduleProgress.current.id}`}>Continue module</Link>
            ) : (
              <Link className="btn-ghost" to="/path">View path</Link>
            )}
          </div>
          <div className="mt-4 h-2 overflow-hidden rounded-full bg-white/10">
            <div
              className="h-full rounded-full bg-sand"
              style={{ width: `${moduleProgress.total ? (moduleProgress.completed / moduleProgress.total) * 100 : 0}%` }}
            />
          </div>

          {Array.isArray(moduleProgress.recent_attempts) && moduleProgress.recent_attempts.some((a) => !a.passed) && (
            <div className="mt-5 border-t border-white/10 pt-4">
              <h3 className="text-sm font-medium text-white/70">Recent module mistakes</h3>
              <ul className="mt-2 space-y-2">
                {moduleProgress.recent_attempts.filter((a) => !a.passed).slice(0, 3).map((a) => (
                  <li key={a.id} className="rounded-xl bg-ink/40 px-3 py-2 text-sm">
                    <div className="flex flex-wrap justify-between gap-2">
                      <span>{a.skill_name}</span>
                      <span className="text-sand">{Math.round(a.score)}% — retry</span>
                    </div>
                    {(a.misses || []).slice(0, 2).map((m, idx) => (
                      <p key={idx} className="mt-1 truncate text-xs text-white/45">{m.stem}</p>
                    ))}
                    <Link className="mt-2 inline-block text-xs text-tideBright" to={`/path/${a.path_item_id}`}>Open module →</Link>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </motion.section>
      )}

      {mission && (
        <motion.section className="panel border border-tideBright/20 bg-gradient-to-br from-tideBright/10 to-transparent p-5 md:p-6" {...fadeUp}>
          <p className="text-xs uppercase tracking-[0.18em] text-tideBright">Today&apos;s Mission</p>
          <h2 className="font-display mt-2 text-2xl font-bold">~{mission.total_minutes || 0} focused minutes</h2>
          <p className="mt-1 text-sm text-white/50">One clear plan — revise, practice, then verify.</p>
          <ol className="mt-5 space-y-2">
            {moduleProgress?.current && (
              <li className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-sand/20 bg-sand/10 px-4 py-3">
                <div className="min-w-0">
                  <p className="font-medium">Continue {moduleProgress.current.skill_name}</p>
                  <p className="text-sm text-white/45">Study + pass the module quiz to unlock the next step.</p>
                </div>
                <Link to={`/path/${moduleProgress.current.id}`} className="btn-primary shrink-0 text-sm">Resume</Link>
              </li>
            )}
            {(mission.items || []).map((item, idx) => (
              <li key={idx} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-white/5 bg-ink/50 px-4 py-3 transition hover:border-tideBright/30">
                <div className="min-w-0">
                  <p className="font-medium">{idx + 1}. {item.title}</p>
                  <p className="text-sm text-white/45">{item.why} · {item.minutes} min</p>
                </div>
                <Link to={item.href || '/assessment'} className="btn-primary shrink-0 text-sm">Start</Link>
              </li>
            ))}
          </ol>
        </motion.section>
      )}

      <StaggerList className="grid gap-3 sm:grid-cols-3">
        {[
          { label: 'Open skill gaps', value: gapStats.total, to: '/gaps', hint: 'vs your target role' },
          { label: 'Critical gaps', value: gapStats.critical, to: '/path', hint: 'prioritize next', tone: 'text-sand' },
          { label: 'Skills in DNA', value: skills.length, to: '/dna', hint: 'with evidence' },
        ].map((m) => (
          <StaggerItem key={m.label}>
            <Link to={m.to} className="panel block p-4 transition hover:border-tideBright/30">
              <p className="text-xs text-white/45">{m.label}</p>
              <p className={`font-display mt-1 text-3xl font-bold ${m.tone || ''}`}>{m.value}</p>
              <p className="mt-1 text-xs text-tideBright">{m.hint} →</p>
            </Link>
          </StaggerItem>
        ))}
      </StaggerList>

      <section className="panel p-5">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <h3 className="font-display text-lg font-semibold">Mastery overview</h3>
          <div className="flex rounded-lg bg-white/5 p-1 text-sm">
            <button type="button" className={`rounded-md px-3 py-1 ${chart === 'radar' ? 'bg-white/10' : 'text-white/50'}`} onClick={() => setChart('radar')}>Radar</button>
            <button type="button" className={`rounded-md px-3 py-1 ${chart === 'bars' ? 'bg-white/10' : 'text-white/50'}`} onClick={() => setChart('bars')}>Bars</button>
          </div>
        </div>
        <div className="h-72">
          {!skills.length ? (
            <p className="flex h-full items-center justify-center text-white/45">Take an assessment to populate mastery.</p>
          ) : chart === 'radar' ? (
            <ResponsiveContainer width="100%" height="100%">
              <RadarChart data={skills}>
                <PolarGrid stroke="#ffffff22" />
                <PolarAngleAxis dataKey="skill" tick={{ fill: '#e8eef8aa', fontSize: 11 }} />
                <Radar dataKey="value" stroke="#2a9d8f" fill="#2a9d8f" fillOpacity={0.3} />
              </RadarChart>
            </ResponsiveContainer>
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={skills}>
                <XAxis dataKey="skill" stroke="#ffffff66" tick={{ fontSize: 11 }} />
                <YAxis stroke="#ffffff66" domain={[0, 100]} />
                <Tooltip contentStyle={{ background: '#1e2a44', border: '1px solid #ffffff22' }} />
                <Bar dataKey="value" fill="#f0a05a" radius={[8, 8, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
      </section>

      <section className="panel overflow-hidden">
        <div className="border-b border-white/10 px-5 py-3">
          <h3 className="font-display text-lg font-semibold">Recent activity</h3>
        </div>
        <div className="divide-y divide-white/5">
          {history.length === 0 && <p className="px-5 py-6 text-sm text-white/45">No assessments yet.</p>}
          {history.map((a) => (
            <div key={a.id} className="flex items-center justify-between gap-3 px-5 py-3 text-sm">
              <span className="capitalize text-white/70">{a.mode}</span>
              <span className="font-medium">{a.score}/10 · {a.level}</span>
              <span className="text-white/35">{a.completed_at ? new Date(a.completed_at).toLocaleDateString() : '—'}</span>
            </div>
          ))}
        </div>
      </section>
    </div>
  )
}
