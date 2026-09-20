import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { motion } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import { PageHeader, Skeleton } from '../components/ui'

export default function OnboardingPage() {
  const { refreshProfile } = useAuth()
  const navigate = useNavigate()
  const [roles, setRoles] = useState([])
  const [roleId, setRoleId] = useState('')
  const [level, setLevel] = useState('beginner')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    supabase.from('roles').select('*').then(({ data }) => setRoles(data || []))
  }, [])

  async function finish(e) {
    e.preventDefault()
    if (!roleId) return setError('Pick a target role')
    setBusy(true)
    setError('')
    const { data: { user } } = await supabase.auth.getUser()
    const { error: err } = await supabase.from('profiles').update({
      target_role_id: roleId,
      experience_level: level,
      onboarding_complete: true,
      updated_at: new Date().toISOString(),
    }).eq('id', user.id)
    setBusy(false)
    if (err) return setError(err.message)
    await refreshProfile()
    navigate('/dashboard')
  }

  if (!roles.length) return <Skeleton className="h-64" />

  return (
    <div className="mx-auto max-w-2xl px-4 py-12">
      <PageHeader title="Set your target" subtitle="We'll measure gaps against this role and build your path." />
      <motion.form onSubmit={finish} className="panel space-y-6 p-6" initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}>
        {error && <p className="text-sm text-red-200">{error}</p>}
        <div className="grid gap-3">
          {roles.map((r) => (
            <button
              key={r.id}
              type="button"
              onClick={() => setRoleId(r.id)}
              className={`rounded-xl border p-4 text-left transition ${roleId === r.id ? 'border-tideBright bg-tideBright/10' : 'border-white/10 bg-white/5 hover:border-white/25'}`}
            >
              <div className="font-display font-semibold">{r.title}</div>
              <p className="mt-1 text-sm text-white/55">{r.description}</p>
            </button>
          ))}
        </div>
        <div>
          <label className="label">Experience level</label>
          <select className="input" value={level} onChange={(e) => setLevel(e.target.value)}>
            <option value="beginner">Beginner</option>
            <option value="intermediate">Intermediate</option>
            <option value="advanced">Advanced</option>
          </select>
        </div>
        <button className="btn-primary w-full" disabled={busy}>{busy ? 'Saving…' : 'Continue to dashboard'}</button>
      </motion.form>
    </div>
  )
}
