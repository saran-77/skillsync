import { useCallback, useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import { PageHeader, EmptyState, Skeleton } from '../components/ui'

export default function PathPage() {
  const { profile } = useAuth()
  const [path, setPath] = useState(null)
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [timerItem, setTimerItem] = useState(null)
  const [seconds, setSeconds] = useState(0)
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
        .select('*, skills(name), resources(id, title, url)')
        .eq('path_id', lp.id)
        .order('sort_order')
      setItems(pi || [])
    }
    setLoading(false)
  }, [profile?.target_role_id])

  useEffect(() => { load() }, [load])

  useEffect(() => {
    if (!timerItem) return undefined
    const id = setInterval(() => setSeconds((s) => s + 1), 1000)
    return () => clearInterval(id)
  }, [timerItem])

  async function generate() {
    setBusy(true)
    const { error } = await supabase.rpc('generate_learning_path')
    setBusy(false)
    if (error) return alert(error.message)
    setLoading(true)
    await load()
  }

  async function setStatus(id, status) {
    const { error } = await supabase.rpc('update_path_item_status', { p_item_id: id, p_status: status })
    if (error) return alert(error.message)
    await load()
  }

  async function toggleBookmark(resourceId) {
    if (!resourceId) return
    const { data: { user } } = await supabase.auth.getUser()
    const { data: existing } = await supabase.from('bookmarks').select('id').eq('user_id', user.id).eq('resource_id', resourceId).maybeSingle()
    if (existing) await supabase.from('bookmarks').delete().eq('id', existing.id)
    else await supabase.from('bookmarks').insert({ user_id: user.id, resource_id: resourceId })
    alert(existing ? 'Bookmark removed' : 'Bookmarked')
  }

  async function stopTimer() {
    if (!timerItem) return
    const minutes = Math.max(0.1, seconds / 60)
    const { data: { user } } = await supabase.auth.getUser()
    await supabase.from('study_sessions').insert({
      user_id: user.id,
      path_item_id: timerItem,
      minutes,
      ended_at: new Date().toISOString(),
    })
    setTimerItem(null)
    setSeconds(0)
  }

  if (loading) return <Skeleton className="h-64" />

  return (
    <div>
      <PageHeader
        title="Learning path"
        subtitle="Ordered by prerequisites and gap priority."
        action={
          <button type="button" className="btn-primary" disabled={busy} onClick={generate}>
            {path ? 'Regenerate' : 'Generate path'}
          </button>
        }
      />

      {path?.why_this_path?.length > 0 && (
        <div className="panel mb-6 p-5">
          <h3 className="font-display font-semibold text-tideBright">Why this path</h3>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-white/60">
            {path.why_this_path.map((w) => <li key={w}>{w}</li>)}
          </ul>
        </div>
      )}

      {timerItem && (
        <div className="mb-4 flex items-center justify-between rounded-xl border border-tideBright/30 bg-tideBright/10 px-4 py-3 text-sm">
          <span>Study timer · {Math.floor(seconds / 60)}:{String(seconds % 60).padStart(2, '0')}</span>
          <button type="button" className="btn-ghost" onClick={stopTimer}>Stop & log</button>
        </div>
      )}

      {!items.length ? (
        <EmptyState title="No path yet" body="Generate a path after setting your role and taking an assessment." action={
          <button type="button" className="btn-primary" onClick={generate}>Generate</button>
        } />
      ) : (
        <div className="space-y-3">
          {items.map((item, i) => (
            <motion.div
              key={item.id}
              className="panel p-4"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-xs uppercase tracking-wide text-white/40">Step {item.sort_order}</p>
                  <h3 className="font-display text-lg font-semibold">{item.skills?.name}</h3>
                  <p className="mt-1 text-sm text-white/55">{item.explanation}</p>
                  {item.resources && (
                    <a className="mt-2 inline-block text-sm text-tideBright underline" href={item.resources.url} target="_blank" rel="noreferrer">
                      {item.resources.title}
                    </a>
                  )}
                </div>
                <span className="rounded-lg bg-white/10 px-2 py-1 text-xs capitalize">{item.status.replace('_', ' ')}</span>
              </div>
              <div className="mt-4 flex flex-wrap gap-2">
                {item.status !== 'completed' && (
                  <button type="button" className="btn-primary text-sm" onClick={() => setStatus(item.id, 'completed')}>Mark done</button>
                )}
                {item.status === 'not_started' && (
                  <button type="button" className="btn-ghost text-sm" onClick={() => setStatus(item.id, 'in_progress')}>Start</button>
                )}
                <button type="button" className="btn-ghost text-sm" onClick={() => { setTimerItem(item.id); setSeconds(0) }}>Study timer</button>
                {item.resource_id && (
                  <button type="button" className="btn-ghost text-sm" onClick={() => toggleBookmark(item.resource_id)}>Bookmark</button>
                )}
              </div>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  )
}
