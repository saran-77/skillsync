import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { PageHeader, EmptyState, Skeleton, MetricBar } from '../components/ui'

function trendMark(t) {
  if (t === 'up') return '↑'
  if (t === 'down') return '↓'
  return '→'
}

export default function SkillDnaPage() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    supabase.rpc('get_skill_dna').then(({ data: d, error: err }) => {
      if (err) setError(err.message)
      else setData(d)
      setLoading(false)
    })
  }, [])

  if (loading) return <Skeleton className="h-80" />
  if (error) return <EmptyState title="Could not load Skill DNA" body={error} />

  const skills = data?.skills || []
  const concepts = data?.concepts || []

  if (!skills.length) {
    return (
      <EmptyState
        title="No Skill DNA yet"
        body="Complete an assessment so we can build evidence-backed mastery."
        action={<Link className="btn-primary" to="/assessment">Take assessment</Link>}
      />
    )
  }

  return (
    <div>
      <PageHeader
        title="Skill DNA"
        subtitle="Evidence-backed mastery, confidence, retention, and diagnosis — not just a score."
      />
      <div className="space-y-4">
        {skills.map((s, i) => {
          const skillConcepts = concepts.filter((c) => c.skill_id === s.skill_id)
          return (
            <motion.div
              key={s.skill_id}
              className="panel p-5"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.04 }}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h3 className="font-display text-xl font-semibold">
                    {s.skill_name}{' '}
                    <span className="text-tideBright">{Math.round(s.mastery_score)}%</span>
                    <span className="ml-2 text-sm text-white/40">{trendMark(s.trend)}</span>
                  </h3>
                  <p className="mt-1 text-sm text-white/55">{s.diagnosis}</p>
                </div>
                <p className="text-xs text-white/40">
                  Evidence: {s.assessment_events || 0} assess · {s.practice_events || 0} practice · {s.flashcard_events || 0} cards
                </p>
              </div>
              <div className="mt-4 grid gap-4 md:grid-cols-2">
                <div>
                  <MetricBar label="Mastery" value={s.mastery_score} />
                  <MetricBar label="Confidence" value={s.confidence} color="bg-sand" />
                  <MetricBar label="Retention" value={s.retention_score} color="bg-white/60" />
                  <MetricBar label="Speed" value={s.speed_score} color="bg-tide" />
                  <MetricBar label="Consistency" value={s.consistency_score} color="bg-tideBright/70" />
                </div>
                <div>
                  <h4 className="mb-2 text-sm font-medium text-white/70">Concept breakdown</h4>
                  {skillConcepts.length === 0 && (
                    <p className="text-sm text-white/40">More concept detail appears as you answer tagged questions.</p>
                  )}
                  {skillConcepts.map((c) => (
                    <div key={c.concept} className="mb-2 flex items-center justify-between text-sm">
                      <span className="capitalize text-white/70">{c.concept.replace(/-/g, ' ')}</span>
                      <span className={c.trend === 'down' ? 'text-sand' : 'text-tideBright'}>
                        {Math.round(c.accuracy)}% {trendMark(c.trend)}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          )
        })}
      </div>
    </div>
  )
}
