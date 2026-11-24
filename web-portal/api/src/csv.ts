// CSV for Excel: UTF-8 with a BOM (Thai shows correctly), CRLF line ends.

/** One cell. Text that a spreadsheet would run as a formula gets a leading apostrophe. */
export function cell(value: unknown): string {
  if (value === null || value === undefined) return '';
  let s = typeof value === 'number' && !Number.isInteger(value) ? String(Math.round(value * 10) / 10) : String(value);
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** A long digit string (student ID) kept as text, so Excel does not show 6.8E+12. */
export function digitsCell(value: string | null): string {
  if (!value || !/^\d+$/.test(value)) return cell(value);
  return `"=""${value}"""`;
}

export function toCsv(header: string[], rows: string[][]): string {
  return '﻿' + [header.map(cell).join(','), ...rows.map((r) => r.join(','))].join('\r\n') + '\r\n';
}
