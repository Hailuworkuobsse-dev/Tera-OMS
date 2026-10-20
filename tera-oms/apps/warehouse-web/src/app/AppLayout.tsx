import { useEffect, useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';

function useClock() {
  const [now, setNow] = useState(new Date());
  useEffect(() => { const t = setInterval(() => setNow(new Date()), 30_000); return () => clearInterval(t); }, []);
  return now;
}
export function AppLayout() {
  const { t } = useI18n();
  const now = useClock();
  return (
    <div className="h-full flex flex-col bg-bg">
      <header className="border-b border-border bg-surface px-6 py-3 flex items-center gap-6">
        <div><p className="text-sm text-muted">{t('app.name')}</p><p className="text-xl font-bold">{t('warehouse.title')}</p></div>
        <nav className="flex gap-1 ml-4">
          <TabLink to="/dock" label={t('warehouse.tab.dock')} />
          <TabLink to="/pick" label={t('warehouse.tab.pick')} />
        </nav>
        <div className="ml-auto text-right">
          <p className="text-2xl font-semibold tabular-nums leading-tight">{now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
          <p className="text-xs text-muted">{now.toLocaleDateString([], { weekday: 'long', month: 'short', day: 'numeric' })}</p>
        </div>
      </header>
      <main className="flex-1 min-h-0 overflow-auto p-6"><Outlet /></main>
    </div>
  );
}
function TabLink({ to, label }: { to: string; label: string }) {
  return <NavLink to={to} className={({ isActive }) => `px-4 py-2 rounded-md text-base font-medium transition ${isActive ? 'bg-bg text-text border border-border' : 'text-muted hover:bg-bg'}`}>{label}</NavLink>;
}
