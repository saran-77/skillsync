import { motion } from 'framer-motion'
import { fadeUp, hoverLift, staggerContainer, staggerItem } from '../lib/motion'

export function PageHeader({ title, subtitle, action }) {
  return (
    <div className="mb-8 flex flex-wrap items-end justify-between gap-4">
      <div>
        <motion.h1
          className="font-display text-3xl font-bold tracking-tight md:text-4xl"
          {...fadeUp}
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
    <motion.div className="panel p-8 text-center" {...fadeUp}>
      <h3 className="font-display text-xl font-semibold">{title}</h3>
      <p className="mt-2 text-white/55">{body}</p>
      {action && <div className="mt-6">{action}</div>}
    </motion.div>
  )
}

export function Skeleton({ className = 'h-24' }) {
  return <div className={`animate-pulse rounded-2xl bg-white/5 ${className}`} />
}

export function PageFade({ children, className = '' }) {
  return (
    <motion.div className={className} {...fadeUp}>
      {children}
    </motion.div>
  )
}

export function StaggerList({ children, className = '' }) {
  return (
    <motion.div className={className} variants={staggerContainer} initial="initial" animate="animate">
      {children}
    </motion.div>
  )
}

export function StaggerItem({ children, className = '' }) {
  return (
    <motion.div className={className} variants={staggerItem} {...hoverLift}>
      {children}
    </motion.div>
  )
}

export function MetricBar({ label, value, color = 'bg-tideBright' }) {
  const v = Math.max(0, Math.min(100, Number(value) || 0))
  return (
    <div className="mb-2">
      <div className="mb-1 flex justify-between text-xs text-white/55">
        <span>{label}</span>
        <span>{Math.round(v)}%</span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-white/10">
        <motion.div
          className={`h-full rounded-full ${color}`}
          initial={{ width: 0 }}
          animate={{ width: `${v}%` }}
          transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
        />
      </div>
    </div>
  )
}

export function Chip({ children, tone = 'default' }) {
  const tones = {
    default: 'bg-white/10 text-white/70',
    tide: 'bg-tideBright/15 text-tideBright',
    sand: 'bg-sand/15 text-sand',
  }
  return (
    <span className={`inline-flex items-center rounded-lg px-2.5 py-1 text-xs font-medium ${tones[tone] || tones.default}`}>
      {children}
    </span>
  )
}
