import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { PageHeader, EmptyState, Skeleton } from '../components/ui'

export default function GapsPage() {
  const [gaps, setGaps] = useState([])
  const [dnaBySkill, setDnaBySkill] = useState({})
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([
      supabase.rpc('compute_gaps'),
      supabase.rpc('get_skill_dna'),
    ]).then(([gapRes, dnaRes]) => {
      if (gapRes.error) setError(gapRes.error.message)
      else setGaps(gapRes.data || [])
      const map = {}
      for (const s of dnaRes.data?.skills || []) map[s.skill_id] = s
      setDnaBySkill(map)
      setLoading(false)
    })
  }, [])

  if (loading) return <Skeleton className="h-64" />
  if (error) {
    return (
      <EmptyState
        title="Set a target role first"
        body={error}
        action={<Link className="btn-primary" to="/onboarding">Onboarding</Link>}
      />
    )
  }

  return (
    <div>
      <PageHeader
        title="Skill gaps"
        subtitle="Ranked by gap size × role importance — with mastery diagnosis."
        action={<Link className="btn-primary" to="/path">Generate path</Link>}
      />
      <div className="space-y-3">
        {gaps.map((g, i) => {
          const dna = dnaBySkill[g.skill_id]
          return (
            <motion.div
              key={g.skill_id}
              className="panel p-4"
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.04 }}
            >
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div className="min-w-0 flex-1">
                  <h3 className="font-display font-semibold">{g.skill_name}</h3>
                  <p className="text-sm text-white/50">{g.reason}</p>
                  {dna?.diagnosis && (
                    <p className="mt-2 text-sm text-sand/90">{dna.diagnosis}</p>
                  )}
                  {dna && (
                    <p className="mt-1 text-xs text-white/40">
                      Mastery {Math.round(dna.mastery_score)}% · Retention {Math.round(dna.retention_score)}% · {dna.trend}
                    </p>
                  )}
                </div>
                <div className="flex items-center gap-4 text-sm">
                  <span className={`rounded-lg px-2 py-1 ${
                    g.priority === 'High' ? 'bg-red-500/20 text-red-200' :
                    g.priority === 'Medium' ? 'bg-sand/20 text-sand' : 'bg-tideBright/20 text-tideBright'
                  }`}>{g.priority}</span>
                  <span>Gap {g.gap}</span>
                </div>
              </div>
            </motion.div>
          )
        })}
        {!gaps.length && <EmptyState title="No gaps" body="You're meeting role requirements — take another assessment later." />}
      </div>
    </div>
  )
}
