import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import { PageHeader } from '../components/ui'

export default function ProfilePage() {
  const { profile, refreshProfile } = useAuth()
  const [roles, setRoles] = useState([])
  const [bookmarks, setBookmarks] = useState([])
  const [fullName, setFullName] = useState(profile?.full_name || '')
  const [roleId, setRoleId] = useState(profile?.target_role_id || '')
  const [level, setLevel] = useState(profile?.experience_level || 'beginner')
  const [msg, setMsg] = useState('')

  useEffect(() => {
    setFullName(profile?.full_name || '')
    setRoleId(profile?.target_role_id || '')
    setLevel(profile?.experience_level || 'beginner')
  }, [profile])

  useEffect(() => {
    supabase.from('roles').select('*').then(({ data }) => setRoles(data || []))
    async function loadBookmarks() {
      const { data: { user } } = await supabase.auth.getUser()
      const { data } = await supabase
        .from('bookmarks')
        .select('id, resources(title, url)')
        .eq('user_id', user.id)
      setBookmarks(data || [])
    }
    loadBookmarks()
  }, [])

  async function save(e) {
    e.preventDefault()
    const { data: { user } } = await supabase.auth.getUser()
    const { error } = await supabase.from('profiles').update({
      full_name: fullName,
      target_role_id: roleId || null,
      experience_level: level,
      updated_at: new Date().toISOString(),
    }).eq('id', user.id)
    setMsg(error ? error.message : 'Saved')
    await refreshProfile()
  }

  return (
    <div className="mx-auto max-w-xl">
      <PageHeader title="Profile" subtitle={`${profile?.xp || 0} XP · streak ${profile?.streak_count || 0}`} />
      <form onSubmit={save} className="panel space-y-4 p-6">
        {msg && <p className="text-sm text-tideBright">{msg}</p>}
        <div>
          <label className="label">Name</label>
          <input className="input" value={fullName} onChange={(e) => setFullName(e.target.value)} />
        </div>
        <div>
          <label className="label">Target role</label>
          <select className="input" value={roleId || ''} onChange={(e) => setRoleId(e.target.value)}>
            <option value="">Select…</option>
            {roles.map((r) => <option key={r.id} value={r.id}>{r.title}</option>)}
          </select>
        </div>
        <div>
          <label className="label">Experience</label>
          <select className="input" value={level} onChange={(e) => setLevel(e.target.value)}>
            <option value="beginner">Beginner</option>
            <option value="intermediate">Intermediate</option>
            <option value="advanced">Advanced</option>
          </select>
        </div>
        <button className="btn-primary" type="submit">Save</button>
      </form>

      <div className="panel mt-6 p-6">
        <h3 className="font-display font-semibold">Bookmarks</h3>
        <ul className="mt-3 space-y-2 text-sm">
          {!bookmarks.length && <li className="text-white/45">No bookmarks yet.</li>}
          {bookmarks.map((b) => (
            <li key={b.id}>
              <a className="text-tideBright underline" href={b.resources?.url} target="_blank" rel="noreferrer">
                {b.resources?.title}
              </a>
            </li>
          ))}
        </ul>
      </div>

      <p className="mt-6 text-xs text-white/40">
        Privacy: AI tutor messages are processed by Groq. Assessment answer keys never leave the server.
      </p>
    </div>
  )
}
