import { useRef, useState } from 'react';
import { useI18n } from '@tera/i18n';
import { Button, StatusPill } from '@tera/ui';
import { parseCsv, downloadTemplate } from './CsvParser';
import { useValidateImport, useCommitImport } from '../hooks';
import type { MasterdataEntityType, ValidateImportResponse, CommitImportResponse } from '../types';
const TYPES: MasterdataEntityType[] = ['distributor', 'vehicle', 'sku'];

export function ImportTab() {
  const { t } = useI18n();
  const fileRef = useRef<HTMLInputElement>(null);
  const [type, setType] = useState<MasterdataEntityType>('distributor');
  const [rows, setRows] = useState<Record<string, string>[] | null>(null);
  const [fileName, setFileName] = useState<string | null>(null);
  const [report, setReport] = useState<ValidateImportResponse | null>(null);
  const [result, setResult] = useState<CommitImportResponse | null>(null);
  const [showValid, setShowValid] = useState(false);
  const [parseError, setParseError] = useState<string | null>(null);
  const validateMut = useValidateImport(); const commitMut = useCommitImport();
  const reset = () => { setRows(null); setFileName(null); setReport(null); setResult(null); setParseError(null); setShowValid(false); if (fileRef.current) fileRef.current.value = ''; };
  const handleFile = async (file: File) => { reset(); setFileName(file.name); try { const text = await file.text(); const parsed = parseCsv(text); if (parsed.length === 0) { setParseError(t('admin.import.empty_file')); return; } setRows(parsed); } catch (e) { setParseError((e as Error).message); } };
  return (
    <div>
      <div className="mb-6"><p className="text-sm font-semibold text-muted uppercase tracking-wide mb-2">{t('admin.import.step1')}</p>
        <div className="flex flex-wrap gap-2">{TYPES.map((ty) => <Button key={ty} variant={type === ty ? 'primary' : 'secondary'} onClick={() => { setType(ty); reset(); }}>{t(`admin.import.type.${ty}`)}</Button>)}</div>
      </div>
      <div className="mb-6"><p className="text-sm font-semibold text-muted uppercase tracking-wide mb-2">{t('admin.import.step2')}</p>
        <div className="flex items-center gap-3 flex-wrap">
          <Button variant="ghost" onClick={() => downloadTemplate(type)}>⬇ {t('admin.import.download_template')}</Button>
          <label className="inline-flex items-center gap-2 px-4 py-2 rounded-md border border-border bg-surface cursor-pointer hover:bg-bg">
            <input ref={fileRef} type="file" accept=".csv,text/csv" onChange={(e) => { const f = e.target.files?.[0]; if (f) void handleFile(f); }} className="sr-only" />
            <span className="text-sm font-medium">{t('admin.import.choose_file')}</span>
          </label>
          {fileName && <span className="text-sm text-muted">{fileName}</span>}
        </div>
        {parseError && <p className="text-sm text-danger mt-2">{parseError}</p>}
      </div>
      {rows && !report && !result && (
        <div className="border border-border rounded-md bg-surface p-4 flex items-center justify-between">
          <p className="text-sm">{rows.length} {t('admin.import.rows_detected')}</p>
          <Button onClick={() => validateMut.mutate({ type, rows }, { onSuccess: (r) => { setReport(r); setResult(null); } })} loading={validateMut.isPending}>{t('admin.import.validate')}</Button>
        </div>
      )}
      {report && !result && (
        <div className="border border-border rounded-md bg-surface">
          <div className="px-4 py-3 border-b border-border flex items-center justify-between flex-wrap gap-2">
            <div className="flex items-center gap-3">
              <StatusPill tone="success">{report.valid_rows} {t('admin.import.valid')}</StatusPill>
              {report.invalid_rows > 0 && <StatusPill tone="danger">{report.invalid_rows} {t('admin.import.invalid')}</StatusPill>}
            </div>
            <div className="flex gap-2">
              <Button variant="secondary" onClick={reset} disabled={commitMut.isPending}>{t('common.cancel')}</Button>
              <Button disabled={report.valid_rows === 0} loading={commitMut.isPending}
                onClick={() => { if (rows) commitMut.mutate({ type, rows }, { onSuccess: (r) => setResult(r) }); }}>
                {t('admin.import.commit', { n: report.valid_rows })}
              </Button>
            </div>
          </div>
          {report.rows.filter((r) => r.status === 'invalid').length > 0 && (
            <div className="p-4 border-b border-border">
              <p className="text-sm font-semibold text-danger mb-2">{t('admin.import.fix_these', { n: report.invalid_rows })}</p>
              <table className="w-full text-xs"><tbody>
                {report.rows.filter((r) => r.status === 'invalid').map((r) => (
                  <tr key={r.row_number} className="border-t border-border">
                    <td className="px-3 py-2 tabular-nums font-mono w-12">{r.row_number}</td>
                    <td className="px-3 py-2 text-danger">{r.errors.join(' · ')}</td>
                  </tr>
                ))}
              </tbody></table>
            </div>
          )}
          <div className="p-4">
            <button onClick={() => setShowValid((v) => !v)} className="text-sm text-primary hover:underline">
              {showValid ? '−' : '+'} {t('admin.import.show_valid', { n: report.valid_rows })}
            </button>
          </div>
        </div>
      )}
      {result && (
        <div className="border border-border rounded-md bg-surface p-6 text-center">
          <div className="text-4xl mb-2">{result.errors.length === 0 ? '✓' : '⚠'}</div>
          <p className="text-lg font-semibold">{t('admin.import.committed', { n: result.inserted })}</p>
          {result.skipped > 0 && <p className="text-sm text-warn mt-1">{t('admin.import.skipped', { n: result.skipped })}</p>}
          <Button onClick={reset} className="mt-4">{t('admin.import.import_another')}</Button>
        </div>
      )}
    </div>
  );
}
