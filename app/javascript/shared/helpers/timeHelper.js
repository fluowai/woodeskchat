import {
  format,
  isSameYear,
  isThisYear,
  isToday,
  isYesterday,
  fromUnixTime,
  formatDistanceToNow,
  differenceInDays,
} from 'date-fns';
import { locale as ptBR, formats as brFormats } from './brLocale';

/**
 * Formats a Unix timestamp into a human-readable time format.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='HH:mm'] - Desired format of the time.
 * @returns {string} Formatted time string.
 */
export const messageStamp = (time, dateFormat = brFormats.time) => {
  const unixTime = fromUnixTime(time);
  return format(unixTime, dateFormat, { locale: ptBR });
};

/**
 * Provides a formatted timestamp, adjusting the format based on the current year.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='dd/MM/yyyy'] - Desired date format.
 * @returns {string} Formatted date string.
 */
export const messageTimestamp = (time, dateFormat = brFormats.date) => {
  const messageTime = fromUnixTime(time);
  const now = new Date();
  const messageDate = format(messageTime, dateFormat, { locale: ptBR });
  if (!isSameYear(messageTime, now)) {
    return format(messageTime, brFormats.fullWithTime, { locale: ptBR });
  }
  return messageDate;
};

/**
 * Formats a Unix timestamp relative to today: the time for today, a caller-
 * supplied label for yesterday, and a date otherwise. The yesterday label is
 * passed in so the caller keeps ownership of translation.
 * @param {number} time - Unix timestamp.
 * @param {string} yesterdayLabel - Localized label shown for yesterday.
 * @returns {string} Formatted timestamp string.
 */
export const relativeDayTimestamp = (time, yesterdayLabel) => {
  const date = fromUnixTime(time);
  if (isToday(date)) return format(date, brFormats.time, { locale: ptBR });
  if (isYesterday(date)) return yesterdayLabel;
  if (isThisYear(date)) return format(date, brFormats.shortDate, { locale: ptBR });
  return format(date, brFormats.date, { locale: ptBR });
};

/**
 * Converts a Unix timestamp to a relative time string (e.g., 3 horas atrás).
 * @param {number} time - Unix timestamp.
 * @returns {string} Relative time string.
 */
export const dynamicTime = time => {
  const unixTime = fromUnixTime(time);
  return formatDistanceToNow(unixTime, { addSuffix: true, locale: ptBR });
};

/**
 * Formats a Unix timestamp into a specified date format.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='dd/MM/yyyy'] - Desired date format.
 * @returns {string} Formatted date string.
 */
export const dateFormat = (time, df = brFormats.date) => {
  const unixTime = fromUnixTime(time);
  return format(unixTime, df, { locale: ptBR });
};

/**
 * Converts a detailed time description into a shorter format, optionally appending 'ago'.
 * Supports English (legacy) and Portuguese (pt-BR) inputs.
 * @param {string} time - Detailed time description (e.g., 'a minute ago' or 'há 2 minutos').
 * @param {boolean} [withAgo=false] - Whether to append 'ago' to the result.
 * @returns {string} Shortened time description.
 */
export const shortTimestamp = (time, withAgo = false) => {
  // Handles both English ("3 minutes ago") and Brazilian Portuguese ("há 3 minutos")
  // outputs. Converts to compact form: 1m, 1h, 1d, 1mo, 1y.
  const suffix = withAgo ? ' ago' : '';

  // Nothing to shorten (already now / empty).
  if (!time || time === 'now' || time === 'agora') return 'now';

  // Remove leading "in", trailing "ago"/"atrás" so the qualifiers below match.
  const stripped = time
    .replace(/\s+(ago|atr[áa]s)$/i, '')
    .replace(/^in\s+/i, '')
    .trim();

  // Sub-minute → "now" (EN: "less than a minute", PT: "menos de um minuto").
  if (/^(h[áa] )?(less than |menos de )(a|an|one|um|uma)?\s*\d*\s*(minute|minuto|second|segundo)s?$/i.test(stripped)) {
    return 'now';
  }

  // Strip qualifiers ("há", then "about/over/almost"/"cerca de/mais de/quase").
  // "há" must come first so wrapped phrases like "há cerca de 1 mês" collapse.
  let normalized = stripped;
  for (const prefix of ['há', 'ha', 'about', 'over', 'almost', 'cerca de', 'mais de', 'quase']) {
    normalized = normalized.replace(new RegExp(`^${prefix}\\s+`, 'i'), '');
  }
  normalized = normalized.replace(/\s+/g, ' ').trim();

  // Number (digits or article/word) → unit → compact form.
  const mappings = [
    [/^(a|an|one|1|um|uma)\s*(minute|minuto)s?$/i, '1m'],
    [/^(\d+)\s*(minute|minuto)s?$/i, '$1m'],
    [/^(a|an|one|1|um|uma)\s*(hour|hora)s?$/i, '1h'],
    [/^(\d+)\s*(hour|hora)s?$/i, '$1h'],
    [/^(a|one|1|um)\s*(day|dia)s?$/i, '1d'],
    [/^(\d+)\s*(day|dia)s?$/i, '$1d'],
    [/^(a|one|1|um)\s*(month(s)?|m[êe]s|meses)$/i, '1mo'],
    [/^(\d+)\s*(month(s)?|m[êe]s|meses)$/i, '$1mo'],
    [/^(a|one|1|um)\s*(year|ano)s?$/i, '1y'],
    [/^(\d+)\s*(year|ano)s?$/i, '$1y'],
  ];

  for (const [pattern, replacement] of mappings) {
    if (normalized.match(pattern)) {
      return `${normalized.replace(pattern, replacement)}${suffix}`;
    }
  }

  return time;
};

/**
 * Formats a duration in seconds into mm:ss or hh:mm:ss.
 * @param {number|string} durationInSeconds - Duration in seconds.
 * @returns {string} Formatted duration string. Empty string for invalid input.
 */
export const formatDuration = durationInSeconds => {
  if (durationInSeconds === null || durationInSeconds === undefined) return '';

  const totalSeconds = Number(durationInSeconds);
  if (Number.isNaN(totalSeconds) || totalSeconds < 0) return '';

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const mm = minutes.toString().padStart(2, '0');
  const ss = seconds.toString().padStart(2, '0');
  if (hours > 0) {
    return `${hours.toString().padStart(2, '0')}:${mm}:${ss}`;
  }
  return `${mm}:${ss}`;
};

/**
 * Calculates the difference in days between now and a given timestamp.
 * @param {Date} now - Current date/time.
 * @param {number} timestampInSeconds - Unix timestamp in seconds.
 * @returns {number} Number of days difference.
 */
export const getDayDifferenceFromNow = (now, timestampInSeconds) => {
  const date = new Date(timestampInSeconds * 1000);
  return differenceInDays(now, date);
};

/**
 * Checks if more than 24 hours have passed since a given timestamp.
 * Useful for determining if retry/refresh actions should be disabled.
 * @param {number} timestamp - Unix timestamp.
 * @returns {boolean} True if more than 24 hours have passed.
 */
export const hasOneDayPassed = timestamp => {
  if (!timestamp) return true; // Defensive check
  return getDayDifferenceFromNow(new Date(), timestamp) >= 1;
};
