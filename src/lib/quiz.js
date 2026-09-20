import { invokeFunction } from './supabase'

/**
 * Fetch AI-generated quiz questions (persisted server-side; no answer keys returned).
 */
export async function fetchAiQuiz({
  skillIds = [],
  skillId = null,
  count = 1,
  difficulty = 3,
  mode = 'adaptive',
  excludeIds = [],
  roleTitle = '',
  topicHint = '',
} = {}) {
  const ids = skillIds?.length ? skillIds : (skillId ? [skillId] : [])
  const data = await invokeFunction('generate-quiz-batch', {
    skill_ids: ids,
    skill_id: skillId,
    count,
    difficulty,
    mode,
    exclude_ids: excludeIds,
    role_title: roleTitle,
    topic_hint: topicHint,
  })
  return {
    questions: data.questions || [],
    source: data.source || 'groq',
    difficulty: data.difficulty ?? difficulty,
    mode: data.mode || mode,
  }
}
