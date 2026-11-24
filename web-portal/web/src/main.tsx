import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Link, Route, Routes } from 'react-router';
import { Shell } from './components';
import { I18nProvider, useI18n } from './i18n';
import ChooseRole from './pages/ChooseRole';
import ClassPage from './pages/ClassPage';
import Landing from './pages/Landing';
import Login from './pages/Login';
import Profile from './pages/Profile';
import StudentLobby from './pages/StudentLobby';
import TeacherLobby from './pages/TeacherLobby';
import { Guard, SessionProvider, useSession } from './session';
import './styles.css';

function Lobby() {
  const { me } = useSession();
  return me?.role === 'teacher' ? <TeacherLobby /> : <StudentLobby />;
}

function NotFound() {
  const { t } = useI18n();
  return (
    <Shell>
      <section className="glass panel narrow">
        <h1>{t('notFound.title')}</h1>
        <Link to="/" className="btn btn-primary">{t('nav.home')}</Link>
      </section>
    </Shell>
  );
}

function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/login" element={<Login />} />
      <Route path="/welcome/role" element={<Guard step="role"><ChooseRole /></Guard>} />
      <Route path="/welcome/profile" element={<Guard step="profile"><Profile /></Guard>} />
      <Route path="/lobby" element={<Guard><Lobby /></Guard>} />
      <Route path="/classes/:id" element={<Guard><ClassPage /></Guard>} />
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <I18nProvider>
      <SessionProvider>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </SessionProvider>
    </I18nProvider>
  </StrictMode>,
);
