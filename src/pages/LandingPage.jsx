import { Link } from 'react-router-dom'
import { motion } from 'framer-motion'

export default function LandingPage() {
  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="pointer-events-none absolute inset-0 bg-mesh opacity-90" />
      <div className="relative mx-auto flex min-h-screen max-w-6xl flex-col px-4 pb-16 pt-8">
        <nav className="flex items-center justify-between">
          <span className="font-display text-2xl font-extrabold tracking-tight">
            Skill<span className="text-tideBright">Sync</span> AI
          </span>
          <div className="flex gap-2">
            <Link to="/login" className="btn-ghost">Sign in</Link>
            <Link to="/signup" className="btn-primary">Get started</Link>
          </div>
        </nav>

        <section className="mt-16 flex flex-1 flex-col justify-center md:mt-24 md:max-w-3xl">
          <motion.p
            className="mb-4 text-sm uppercase tracking-[0.2em] text-sand"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
          >
            Adaptive learning for students
          </motion.p>
          <motion.h1
            className="font-display text-5xl font-extrabold leading-[1.05] tracking-tight md:text-7xl"
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.05 }}
          >
            SkillSync
          </motion.h1>
          <motion.p
            className="mt-6 max-w-xl text-lg text-white/65 md:text-xl"
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.12 }}
          >
            Measure what you know, close the gaps for your target role, and study with a path that adapts as you improve.
          </motion.p>
          <motion.div
            className="mt-10 flex flex-wrap gap-3"
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            <Link to="/signup" className="btn-primary px-6 py-3 text-base shadow-glow">
              Start learning free
            </Link>
            <Link to="/login" className="btn-ghost px-6 py-3 text-base">
              I have an account
            </Link>
          </motion.div>
        </section>

        <motion.div
          className="mt-auto grid gap-4 pt-16 md:grid-cols-3"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.35 }}
        >
          {[
            ['Assess', 'Adaptive quizzes with server-side scoring'],
            ['Path', 'Modules with open docs, courses, and repos'],
            ['DNA', 'Evidence-backed mastery — not vanity scores'],
          ].map(([t, d], i) => (
            <motion.div
              key={t}
              className="panel p-5"
              whileHover={{ y: -4 }}
              transition={{ type: 'spring', stiffness: 300, damping: 22 }}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              custom={i}
            >
              <h3 className="font-display text-lg font-semibold text-tideBright">{t}</h3>
              <p className="mt-2 text-sm text-white/55">{d}</p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </div>
  )
}
