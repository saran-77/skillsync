import { useEffect, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { supabase } from '../lib/supabase'
import { PageHeader, EmptyState, Skeleton } from '../components/ui'

export default function FlashcardsPage() {
  const [cards, setCards] = useState([])
  const [index, setIndex] = useState(0)
  const [flipped, setFlipped] = useState(false)
  const [loading, setLoading] = useState(true)

  async function load() {
    const { data: { user } } = await supabase.auth.getUser()
    const { data } = await supabase
      .from('flashcards')
      .select('*')
      .eq('user_id', user.id)
      .lte('due_at', new Date().toISOString())
      .order('due_at')
      .limit(30)
    setCards(data || [])
    setIndex(0)
    setFlipped(false)
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  async function rate(quality) {
    const card = cards[index]
    if (!card) return
    await supabase.rpc('review_flashcard', { p_card_id: card.id, p_quality: quality })
    if (index + 1 >= cards.length) await load()
    else {
      setIndex(index + 1)
      setFlipped(false)
    }
  }

  if (loading) return <Skeleton className="h-64" />
  if (!cards.length) {
    return <EmptyState title="No cards due" body="Missed assessment questions become flashcards automatically." />
  }

  const card = cards[index]

  return (
    <div>
      <PageHeader title="Flashcards" subtitle={`${index + 1} of ${cards.length} due`} />
      <AnimatePresence mode="wait">
        <motion.button
          key={card.id + String(flipped)}
          type="button"
          className="panel mx-auto flex min-h-[220px] w-full max-w-xl cursor-pointer items-center justify-center p-8 text-center"
          onClick={() => setFlipped(!flipped)}
          initial={{ rotateY: 90, opacity: 0 }}
          animate={{ rotateY: 0, opacity: 1 }}
          exit={{ rotateY: -90, opacity: 0 }}
          transition={{ duration: 0.25 }}
        >
          <p className="text-lg leading-relaxed">{flipped ? card.back : card.front}</p>
        </motion.button>
      </AnimatePresence>
      <p className="mt-3 text-center text-sm text-white/40">Tap card to flip</p>
      {flipped && (
        <div className="mt-6 flex justify-center gap-2">
          <button type="button" className="btn-ghost" onClick={() => rate(1)}>Again</button>
          <button type="button" className="btn-ghost" onClick={() => rate(3)}>Hard</button>
          <button type="button" className="btn-primary" onClick={() => rate(5)}>Easy</button>
        </div>
      )}
    </div>
  )
}
