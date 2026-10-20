import { useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button } from '@tera/ui';
import type { CreditStopRow, OverrideRequest } from '../types';

interface Props {
  row: CreditStopRow;
  onSubmit: (req: OverrideRequest) => void;
  onCancel: () => void;
  isPending: boolean;
  errorMessage?: string;
}
function defaultExpiry(): string { return new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(); }

export function OverrideDialog({ row, onSubmit, onCancel, isPending, errorMessage }: Props) {
  const { t } = useI18n();
  const [reason, setReason] = useState('');
  const [expiresAt, setExpiresAt] = useState(defaultExpiry());
  const canSubmit = reason.trim().length >= 5 && !isPending;

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" role="dialog" aria-modal>
      <div className="bg-surface rounded-lg border border-border w-full max-w-lg p-6">
        <h2 className="text-lg font-semibold">{t('credit.override')}</h2>
        <p className="text-sm text-muted mt-1">{row.distributor_name} · {row.region}</p>
        <label className="block mt-4 text-sm">
          <span className="text-muted">{t('credit.override_reason')}</span>
          <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3}
            className="mt-1 w-full rounded-md border border-border bg-bg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary" />
        </label>
        <label className="block mt-4 text-sm">
          <span className="text-muted">{t('credit.override_expires')}</span>
          <input type="datetime-local" value={expiresAt.slice(0, 16)}
            onChange={(e) => setExpiresAt(new Date(e.target.value).toISOString())}
            className="mt-1 w-full rounded-md border border-border bg-bg px-3 py-2" />
        </label>
        {errorMessage && <p className="mt-3 text-sm text-danger">{errorMessage}</p>}
        <div className="mt-6 flex justify-end gap-2">
          <Button variant="secondary" onClick={onCancel} disabled={isPending}>{t('common.cancel')}</Button>
          <Button variant="danger" disabled={!canSubmit} loading={isPending}
            onClick={() => onSubmit({ distributor_id: row.distributor_id, reason: reason.trim(), expires_at: expiresAt })}>
            {t('credit.override_confirm')}
          </Button>
        </div>
      </div>
    </div>
  );
}
