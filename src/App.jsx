import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { AnimatePresence } from 'framer-motion'
import { AuthProvider, useAuth } from './context/AuthContext'
import { ProtectedRoute } from './components/ProtectedRoute'
import AppLayout from './components/AppLayout'
import LandingPage from './pages/LandingPage'
import LoginPage from './pages/LoginPage'
import SignupPage from './pages/SignupPage'
import OnboardingPage from './pages/OnboardingPage'
import DashboardPage from './pages/DashboardPage'
import AssessmentPage from './pages/AssessmentPage'
import GapsPage from './pages/GapsPage'
import PathPage from './pages/PathPage'
import ChallengePage from './pages/ChallengePage'
import FlashcardsPage from './pages/FlashcardsPage'
import InterviewPage from './pages/InterviewPage'
import TutorPage from './pages/TutorPage'
import ProfilePage from './pages/ProfilePage'
import PracticePage from './pages/PracticePage'
import SkillDnaPage from './pages/SkillDnaPage'
import ModulePage from './pages/ModulePage'

function PublicOnly({ children }) {
  const { session, loading } = useAuth()
  if (loading) return null
  if (session) return <Navigate to="/dashboard" replace />
  return children
}

function AnimatedRoutes() {
  const location = useLocation()
  return (
    <AnimatePresence mode="wait">
      <Routes location={location} key={location.pathname}>
        <Route path="/" element={<PublicOnly><LandingPage /></PublicOnly>} />
        <Route path="/login" element={<PublicOnly><LoginPage /></PublicOnly>} />
        <Route path="/signup" element={<PublicOnly><SignupPage /></PublicOnly>} />
        <Route path="/onboarding" element={<ProtectedRoute requireOnboarding={false}><OnboardingPage /></ProtectedRoute>} />
        <Route element={<ProtectedRoute><AppLayout /></ProtectedRoute>}>
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/dna" element={<SkillDnaPage />} />
          <Route path="/assessment" element={<AssessmentPage />} />
          <Route path="/gaps" element={<GapsPage />} />
          <Route path="/path" element={<PathPage />} />
          <Route path="/path/:itemId" element={<ModulePage />} />
          <Route path="/challenge" element={<ChallengePage />} />
          <Route path="/flashcards" element={<FlashcardsPage />} />
          <Route path="/interview" element={<InterviewPage />} />
          <Route path="/practice" element={<PracticePage />} />
          <Route path="/tutor" element={<TutorPage />} />
          <Route path="/profile" element={<ProfilePage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AnimatePresence>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AnimatedRoutes />
      </BrowserRouter>
    </AuthProvider>
  )
}
