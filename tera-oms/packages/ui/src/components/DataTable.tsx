import type { ReactNode } from 'react';

export interface Column<T> {
  key: string;
  header: ReactNode;
  render: (row: T) => ReactNode;
  align?: 'left' | 'right' | 'center';
  width?: string;
}

interface Props<T> {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  emptyMessage: ReactNode;
}

export function DataTable<T>({ columns, rows, rowKey, onRowClick, emptyMessage }: Props<T>) {
  if (rows.length === 0) {
    return <div className="border border-border rounded-md bg-surface px-6 py-10 text-center text-muted text-sm">{emptyMessage}</div>;
  }
  return (
    <div className="border border-border rounded-md bg-surface overflow-hidden">
      <table className="w-full text-sm">
        <thead className="bg-bg border-b border-border">
          <tr>
            {columns.map((c) => (
              <th key={c.key} style={c.width ? { width: c.width } : undefined} className={`px-4 py-3 font-medium text-muted text-${c.align ?? 'left'}`}>
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={rowKey(row)} onClick={onRowClick ? () => onRowClick(row) : undefined}
                className={`border-b border-border last:border-0 ${onRowClick ? 'cursor-pointer hover:bg-bg' : ''}`}>
              {columns.map((c) => (
                <td key={c.key} className={`px-4 py-3 text-${c.align ?? 'left'}`}>{c.render(row)}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
