import { NavLink, Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';
const NAV = [
  { to: '/masterdata', key: 'admin.nav.masterdata' },
  { to: '/constraints', key: 'admin.nav.constraints' },
  { to: '/audit', key: 'admin.nav.audit' },
  { to: '/notifications', key: 'admin.nav.notifications' },
  { to: '/jobs', key: 'admin.nav.jobs' },
  { to: '/monitoring', key: 'admin.nav.monitoring' },
];
export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="h-full flex">
      <aside className="w-60 shrink-0 border-r border-border bg-surface flex flex-col">
        <div className="px-5 py-4 border-b border-border"><p className="text-xs text-muted uppercase tracking-wide">{t('app.name')}</p><p className="text-lg font-bold">{t('admin.title')}</p></div>
        <nav className="flex-1 p-2">{NAV.map((n) => <NavLink key={n.to} to={n.to} className={({ isActive }) => `block px-3 py-2 rounded-md text-sm ${isActive ? 'bg-bg text-text font-medium' : 'text-muted hover:bg-bg'}`}>{t(n.key)}</NavLink>)}</nav>
      </aside>
      <main className="flex-1 min-w-0 overflow-auto p-6"><Outlet /></main>
    </div>
  );
}
