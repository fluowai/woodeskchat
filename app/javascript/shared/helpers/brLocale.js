import { format } from 'date-fns';
import ptBRDateFns from 'date-fns/locale/pt-BR';

// date-fns 2.21.1 exposes each locale as the DEFAULT export of its subpath
// (module.exports = locale). Named imports ({ ptBR }) are undefined here;
// keep the default import so Vite's CJS interop binds the locale correctly.

/**
 * Centralized Brazilian Portuguese locale for date-fns.
 * Import this instead of hardcoded English format strings.
 */
export const locale = ptBRDateFns;

/**
 * BR date/time format tokens (date-fns syntax).
 */
export const formats = {
  // Time: 14:30 (24h, no AM/PM)
  time: 'HH:mm',
  // Date: 10/09/2026
  date: 'dd/MM/yyyy',
  // DateTime: 10/09/2026 14:30
  dateTime: 'dd/MM/yyyy HH:mm',
  // Short date: 10/09
  shortDate: 'dd/MM',
  // Month year: setembro de 2026
  monthYear: "MMMM 'de' yyyy",
  // Relative day + time: 10/09 14:30
  relativeDayTime: 'dd/MM HH:mm',
  // Full: 10 de setembro de 2026
  full: "d 'de' MMMM 'de' yyyy",
  // Full with time: 10 de setembro de 2026 às 14:30
  fullWithTime: "d 'de' MMMM 'de' yyyy 'às' HH:mm",
  // CSV export: 10/09/2026 14:30
  csv: 'dd/MM/yyyy HH:mm',
};

/**
 * BR number formatting via Intl.NumberFormat.
 */
const brNumberFormatter = new Intl.NumberFormat('pt-BR', {
  minimumFractionDigits: 0,
  maximumFractionDigits: 2,
});

/**
 * Format a number in BR style: 1.234,56
 * @param {number} value
 * @returns {string}
 */
export const formatNumberBR = value => brNumberFormatter.format(value);

/**
 * Format currency in BRL: R$ 1.234,56
 * @param {number} value
 * @returns {string}
 */
export const formatCurrencyBR = value =>
  new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value);

/**
 * Format a percentage in BR style: 75,3%
 * @param {number} value - e.g. 0.753 for 75.3%
 * @param {boolean} asDecimal - if true, value is already 75.3 not 0.753
 * @returns {string}
 */
export const formatPercentBR = (value, asDecimal = false) => {
  const fraction = asDecimal ? value / 100 : value;
  return new Intl.NumberFormat('pt-BR', {
    style: 'percent',
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  }).format(fraction);
};

/**
 * Format a date for CSV exports: DD/MM/YYYY HH:MM
 * @param {Date|string|number} date
 * @returns {string}
 */
export const formatForCSV = date => {
  const d = date instanceof Date ? date : new Date(date);
  return format(d, formats.csv, { locale: ptBRDateFns });
};
