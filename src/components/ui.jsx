import { motion } from 'framer-motion'

export function PageHeader({ title, subtitle, action }) {
  return (
    <div className="mb-8 flex flex-wrap items-end justify-between gap-4">
      <div>
        <motion.h1
          className="font-display text-3xl font-bold tracking-tight md:text-4xl"
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
        >
          {title}
        </motion.h1>
        {subtitle && <p className="mt-2 max-w-2xl text-white/55">{subtitle}</p>}
      </div>
      {action}
    </div>
  )
}

export function EmptyState({ title, body, action }) {
  return (
    <div className="panel p-8 text-center">
      <h3 className="font-display text-xl font-semibold">{title}</h3>
      <p className="mt-2 text-white/55">{body}</p>
      {action && <div className="mt-6">{action}</div>}
    </div>
  )
}

export function Skeleton({ className = 'h-24' }) {
  return <div className={`animate-pulse rounded-2xl bg-white/5 ${className}`} />
}
