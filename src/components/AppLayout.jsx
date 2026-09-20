import { useEffect, useRef, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { motion, AnimatePresence } from 'framer-motion'
import { useAuth } from '../context/AuthContext'

const primary = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/dna', label: 'DNA' },
  { to: '/assessment', label: 'Assess' },
  { to: '/gaps', label: 'Gaps' },
  { to: '/path', label: 'Path' },
  { to: '/tutor', label: 'Tutor' },
]

const more = [
  { to: '/challenge', label: 'Daily Challenge' },
  { to: '/flashcards', label: 'Flashcards' },
  { to: '/interview', label: 'Interview' },
  { to: '/practice', label: 'Practice' },
  { to: '/profile', label: 'Profile' },
]

const allMobile = [
  ...primary,
  { to: '/challenge', label: 'Daily' },
  { to: '/flashcards', label: 'Cards' },
  { to: '/interview', label: 'Interview' },
  { to: '/practice', label: 'Practice' },
  { to: '/profile', label: 'Profile' },
]

export default function AppLayout() {
  const { profile, signOut } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [open, setOpen] = useState(false)
  const menuRef = useRef(null)
  const moreActive = more.some((l) => location.pathname === l.to || location.pathname.startsWith(`${l.to}/`))

  useEffect(() => {
    function onDoc(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) setOpen(false)
    }
    function onKey(e) {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onDoc)
      document.removeEventListener('keydown', onKey)
    }
  }, [])

  useEffect(() => {
    setOpen(false)
  }, [location.pathname])

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-40 border-b border-white/10 bg-ink/80 backdrop-blur-lg">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <button type="button" onClick={() => navigate('/dashboard')} className="font-display text-xl font-bold tracking-tight text-mist">
            Skill<span className="text-tideBright">Sync</span>
          </button>
          <div className="hidden items-center gap-1 md:flex">
            {primary.map((l) => (
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
            <div className="relative" ref={menuRef}>
              <button
                type="button"
                aria-expanded={open}
                aria-haspopup="menu"
                className={`rounded-lg px-2.5 py-1.5 text-sm transition ${
                  moreActive || open ? 'bg-white/10 text-mist' : 'text-white/55 hover:text-mist'
                }`}
                onClick={() => setOpen((v) => !v)}
              >
                More{moreActive ? ' ·' : ''}
              </button>
              <AnimatePresence>
                {open && (
                  <motion.div
                    role="menu"
                    initial={{ opacity: 0, y: 6 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 4 }}
                    className="absolute right-0 mt-2 min-w-[12.5rem] rounded-xl border border-white/10 bg-dusk/95 p-1.5 shadow-glow backdrop-blur-md"
                  >
                    {more.map((l) => (
                      <NavLink
                        key={l.to}
                        to={l.to}
                        role="menuitem"
                        onClick={() => setOpen(false)}
                        className={({ isActive }) =>
                          `flex items-center justify-between rounded-lg px-3 py-2 text-sm ${
                            isActive ? 'bg-white/10 text-mist' : 'text-white/65 hover:bg-white/5'
                          }`
                        }
                      >
                        <span>{l.label}</span>
                        {location.pathname === l.to && <span className="text-xs text-tideBright">●</span>}
                      </NavLink>
                    ))}
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
          <div className="flex items-center gap-3 text-sm">
            <span className="hidden rounded-lg bg-white/5 px-2 py-1 text-white/55 sm:inline">
              {profile?.xp ?? 0} XP · {profile?.streak_count ?? 0}d
            </span>
            <button type="button" className="btn-ghost text-sm" onClick={() => signOut().then(() => navigate('/'))}>
              Sign out
            </button>
          </div>
        </div>
        <div className="flex gap-1 overflow-x-auto px-3 pb-2 md:hidden">
          {allMobile.map((l) => (
            <NavLink
              key={l.to}
              to={l.to}
              className={({ isActive }) =>
                `shrink-0 rounded-lg px-2.5 py-1 text-xs ${isActive ? 'bg-white/15 text-mist' : 'bg-white/5 text-white/70'}`
              }
            >
              {l.label}
            </NavLink>
          ))}
        </div>
      </header>
      <motion.main
        className="mx-auto max-w-6xl px-4 py-8"
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
      >
        <Outlet />
      </motion.main>
    </div>
  )
}
