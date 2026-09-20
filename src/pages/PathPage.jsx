import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import { PageHeader, EmptyState, Skeleton, Chip } from '../components/ui'
import { fadeUp, hoverLift } from '../lib/motion'

export default function PathPage() {
  const { profile } = useAuth()
  const [path, setPath] = useState(null)
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user || !profile?.target_role_id) {
      setLoading(false)
      return
    }
    const { data: lp } = await supabase
      .from('learning_paths')
      .select('*')
      .eq('user_id', user.id)
      .eq('role_id', profile.target_role_id)
      .maybeSingle()
    setPath(lp)
    if (lp) {
      const { data: pi } = await supabase
        .from('path_items')
        .select('*, skills(name)')
        .eq('path_id', lp.id)
        .order('sort_order')
      setItems(pi || [])
    } else {
      setItems([])
    }
    setLoading(false)
  }, [profile?.target_role_id])

  useEffect(() => { load() }, [load])

  const done = useMemo(() => items.filter((i) => i.status === 'completed').length, [items])

  async function updatePath() {
    setBusy(true)
    const { error } = await supabase.rpc('generate_learning_path')
    setBusy(false)
    if (error) return alert(error.message)
    setLoading(true)
    await load()
  }

  async function resetPath() {
    if (!window.confirm('Reset your entire learning path? Completed modules, quiz scores, and attempts will be wiped.')) {
      return
    }
    setBusy(true)
    const { error } = await supabase.rpc('reset_learning_path')
    setBusy(false)
    if (error) return alert(error.message)
    setLoading(true)
    await load()
  }

  if (loading) return <Skeleton className="h-64" />

  return (
    <div>
      <PageHeader
        title="Learning path"
        subtitle={
          path
            ? 'Update adds new gap skills without wiping progress. Reset starts over.'
            : 'Study each module, pass the scenario quiz (70%), unlock the next.'
        }
        action={
          path ? (
            <div className="flex flex-wrap gap-2">
              <button type="button" className="btn-primary" disabled={busy} onClick={updatePath}>
                Update path
              </button>
              <button type="button" className="btn-ghost" disabled={busy} onClick={resetPath}>
                Reset path…
              </button>
            </div>
          ) : (
            <button type="button" className="btn-primary" disabled={busy} onClick={updatePath}>
              Generate path
            </button>
          )
        }
      />

      {items.length > 0 && (
        <motion.div className="panel mb-6 p-4" {...fadeUp}>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <p className="font-display text-lg font-semibold">{done} / {items.length} modules passed</p>
            <div className="h-2 w-full max-w-xs overflow-hidden rounded-full bg-white/10 sm:w-48">
              <div className="h-full rounded-full bg-tideBright" style={{ width: `${items.length ? (done / items.length) * 100 : 0}%` }} />
            </div>
          </div>
        </motion.div>
      )}

      {path?.why_this_path?.length > 0 && (
        <motion.div className="panel mb-6 p-5" {...fadeUp}>
          <h3 className="font-display font-semibold text-tideBright">Why this path</h3>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-white/60">
            {path.why_this_path.map((w) => <li key={w}>{w}</li>)}
          </ul>
        </motion.div>
      )}

      {!items.length ? (
        <EmptyState
          title="No path yet"
          body="Generate a gated path for your target role."
          action={<button type="button" className="btn-primary" onClick={updatePath}>Generate</button>}
        />
      ) : (
        <div className="space-y-3">
          {items.map((item, i) => {
            const locked = item.status === 'locked'
            return (
              <motion.div
                key={item.id}
                className={`panel p-4 ${locked ? 'opacity-60' : ''}`}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.04 }}
                {...(locked ? {} : hoverLift)}
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="text-xs uppercase tracking-wide text-white/40">Module {item.sort_order}</p>
                    <h3 className="font-display text-lg font-semibold">
                      {locked ? 'Locked · ' : ''}{item.skills?.name}
                    </h3>
                    <p className="mt-1 text-sm text-white/55">{item.explanation}</p>
                    <div className="mt-2 flex flex-wrap gap-2">
                      <Chip tone={item.status === 'completed' ? 'tide' : locked ? 'default' : 'sand'}>
                        {item.status.replace('_', ' ')}
                      </Chip>
                      {item.best_score != null && <Chip>Best {Math.round(item.best_score)}%</Chip>}
                      {item.attempts > 0 && <Chip>{item.attempts} attempt(s)</Chip>}
                    </div>
                  </div>
                  {!locked ? (
                    <Link className="btn-primary text-sm" to={`/path/${item.id}`}>
                      {item.status === 'completed' ? 'Review module' : 'Open module'}
                    </Link>
                  ) : (
                    <span className="rounded-xl bg-white/5 px-3 py-2 text-xs text-white/40">Pass previous quiz</span>
                  )}
                </div>
              </motion.div>
            )
          })}
        </div>
      )}
    </div>
  )
}
