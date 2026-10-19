import type { ReactNode } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { I18nProvider, type Locale } from '@tera/i18n';
import { queryClient } from '../api/queryClient';

const locale = (import.meta.env.VITE_DEFAULT_LOCALE as Locale) ?? 'am';

export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <I18nProvider initialLocale={locale}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </I18nProvider>
  );
}
