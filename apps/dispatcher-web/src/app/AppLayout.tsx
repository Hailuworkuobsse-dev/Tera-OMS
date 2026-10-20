import { NavLink, Outlet } from 'react-router-dom';
import { useI18n } from '@tera/i18n';

const NAV = [
  { to: '/routes',  key: 'nav.routes' },
  { to: '/builder', key: 'nav.route_builder' },
  { to: '/board',   key: 'nav.dispatch_board' },
  { to: '/credit',  key: 'nav.credit' },
];

export function AppLayout() {
  const { t } = useI18n();
  return (
    <div className="min-h-full flex">
      <aside className="w-56 shrink-0 border-r border-border bg-surface flex flex-col">
        <div className="px-5 py-4 border-b border-border">
          <p className="text-sm text-muted">{t('app.name')}</p>
          <p className="text-base font-semibold">{t('nav.dispatch')}</p>
        </div>
        <nav className="flex-1 p-2">
          {NAV.map((n) => (
            <NavLink key={n.to} to={n.to}
              className={({ isActive }) =>
                `block px-3 py-2 rounded-md text-sm ${
                  isActive ? 'bg-bg text-text font-medium' : 'text-muted hover:bg-bg'
                }`
              }>
              {t(n.key)}
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="flex-1 min-w-0 p-6"><Outlet /></main>
    </div>
  );
}
