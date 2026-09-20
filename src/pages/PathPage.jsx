import { useCallback, useEffect, useMemo, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import { PageHeader, EmptyState, Skeleton, Chip } from '../components/ui'
import { fadeUp, hoverLift } from '../lib/motion'

const typeTone = {
  docs: 'tide',
  course: 'sand',
  article: 'default',
  repo: 'tide',
}

export default function PathPage() {
  const { profile } = useAuth()
  const [path, setPath] = useState(null)
  const [items, setItems] = useState([])
  const [resourcesBySkill, setResourcesBySkill] = useState({})
  const [expanded, setExpanded] = useState({})
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
      const list = pi || []
      setItems(list)
      const ids = [...new Set(list.map((i) => i.skill_id).filter(Boolean))]
      if (ids.length) {
        const { data: res } = await supabase
          .from('resources')
          .select('id, skill_id, title, url, type, difficulty')
          .in('skill_id', ids)
          .order('difficulty')
        const map = {}
        for (const r of res || []) {
          if (!map[r.skill_id]) map[r.skill_id] = []
          map[r.skill_id].push(r)
        }
        setResourcesBySkill(map)
      }
    }
    setLoading(false)
  }, [profile?.target_role_id])

  useEffect(() => { load() }, [load])

  useEffect(() => {
    if (!timerItem) return undefined
    const id = setInterval(() => setSeconds((s) => s + 1), 1000)
    return () => clearInterval(id)
  }, [timerItem])

  const openCount = useMemo(() => Object.values(expanded).filter(Boolean).length, [expanded])

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
        subtitle="Modules ordered by gaps and prerequisites — each with open study materials."
        action={
          <button type="button" className="btn-primary" disabled={busy} onClick={generate}>
            {path ? 'Regenerate' : 'Generate path'}
          </button>
        }
      />

      {path?.why_this_path?.length > 0 && (
        <motion.div className="panel mb-6 p-5" {...fadeUp}>
          <h3 className="font-display font-semibold text-tideBright">Why this path</h3>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-white/60">
            {path.why_this_path.map((w) => <li key={w}>{w}</li>)}
          </ul>
        </motion.div>
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
          <p className="text-xs text-white/40">{items.length} modules · {openCount} expanded</p>
          {items.map((item, i) => {
            const mats = resourcesBySkill[item.skill_id] || []
            const isOpen = !!expanded[item.id]
            return (
              <motion.div
                key={item.id}
                className="panel overflow-hidden"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.04 }}
                {...hoverLift}
              >
                <button
                  type="button"
                  className="flex w-full flex-wrap items-start justify-between gap-3 p-4 text-left"
                  onClick={() => setExpanded((e) => ({ ...e, [item.id]: !e[item.id] }))}
                >
                  <div>
                    <p className="text-xs uppercase tracking-wide text-white/40">Module {item.sort_order}</p>
                    <h3 className="font-display text-lg font-semibold">{item.skills?.name}</h3>
                    <p className="mt-1 text-sm text-white/55">{item.explanation}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Chip>{mats.length} resources</Chip>
                    <span className="rounded-lg bg-white/10 px-2 py-1 text-xs capitalize">{item.status.replace('_', ' ')}</span>
                    <span className="text-white/40">{isOpen ? '−' : '+'}</span>
                  </div>
                </button>

                <AnimatePresence initial={false}>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.28 }}
                      className="overflow-hidden border-t border-white/10"
                    >
                      <div className="space-y-4 p-4">
                        <div>
                          <h4 className="mb-2 text-sm font-medium text-white/70">Study materials</h4>
                          <ul className="space-y-2">
                            {mats.length === 0 && <li className="text-sm text-white/40">No linked materials yet.</li>}
                            {mats.map((r) => (
                              <li key={r.id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-ink/40 px-3 py-2">
                                <div className="flex min-w-0 items-center gap-2">
                                  <Chip tone={typeTone[r.type] || 'default'}>{r.type}</Chip>
                                  <a className="truncate text-sm text-tideBright underline" href={r.url} target="_blank" rel="noreferrer">
                                    {r.title}
                                  </a>
                                </div>
                                <button type="button" className="btn-ghost text-xs" onClick={() => toggleBookmark(r.id)}>Bookmark</button>
                              </li>
                            ))}
                          </ul>
                        </div>
                        <div className="flex flex-wrap gap-2">
                          {item.status !== 'completed' && (
                            <button type="button" className="btn-primary text-sm" onClick={() => setStatus(item.id, 'completed')}>Mark done</button>
                          )}
                          {item.status === 'not_started' && (
                            <button type="button" className="btn-ghost text-sm" onClick={() => setStatus(item.id, 'in_progress')}>Start</button>
                          )}
                          <button type="button" className="btn-ghost text-sm" onClick={() => { setTimerItem(item.id); setSeconds(0) }}>Study timer</button>
                        </div>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </motion.div>
            )
          })}
        </div>
      )}
    </div>
  )
}
