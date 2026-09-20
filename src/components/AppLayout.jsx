import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { motion } from 'framer-motion'
import { useAuth } from '../context/AuthContext'

const links = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/assessment', label: 'Assess' },
  { to: '/gaps', label: 'Gaps' },
  { to: '/path', label: 'Path' },
  { to: '/challenge', label: 'Daily' },
  { to: '/flashcards', label: 'Cards' },
  { to: '/interview', label: 'Interview' },
  { to: '/practice', label: 'Practice' },
  { to: '/tutor', label: 'Tutor' },
  { to: '/profile', label: 'Profile' },
]

export default function AppLayout() {
  const { profile, signOut } = useAuth()
  const navigate = useNavigate()

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-40 border-b border-white/10 bg-ink/80 backdrop-blur-lg">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <button type="button" onClick={() => navigate('/dashboard')} className="font-display text-xl font-bold tracking-tight text-mist">
            Skill<span className="text-tideBright">Sync</span>
          </button>
          <div className="hidden items-center gap-1 md:flex">
            {links.map((l) => (
              <NavLink
                key={l.to}
                to={l.to}
                className={({ isActive }) =>
                  `rounded-lg px-2.5 py-1.5 text-sm transition ${isActive ? 'bg-white/10 text-mist' : 'text-white/55 hover:text-mist'}`
                }
              >
                {l.label}
              </NavLink>
            ))}
          </div>
          <div className="flex items-center gap-3 text-sm">
            <span className="hidden text-white/50 sm:inline">{profile?.xp ?? 0} XP · {profile?.streak_count ?? 0}🔥</span>
            <button type="button" className="btn-ghost text-sm" onClick={() => signOut().then(() => navigate('/'))}>
              Sign out
            </button>
          </div>
        </div>
        <div className="flex gap-1 overflow-x-auto px-3 pb-2 md:hidden">
          {links.map((l) => (
            <NavLink key={l.to} to={l.to} className="shrink-0 rounded-lg bg-white/5 px-2.5 py-1 text-xs text-white/70">
              {l.label}
            </NavLink>
          ))}
        </div>
      </header>
      <motion.main
        className="mx-auto max-w-6xl px-4 py-8"
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
      >
        <Outlet />
      </motion.main>
    </div>
  )
}
