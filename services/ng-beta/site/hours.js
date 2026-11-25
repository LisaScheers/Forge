export const dayNames = ['Zondag', 'Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'];

export function seasonFor(month, day) {
  const dateNumber = month * 100 + day;
  return dateNumber >= 315 && dateNumber <= 1014 ? 'summer' : 'winter';
}

export function weekFor(season) {
  const weekday = season === 'summer'
    ? [['10:00', '12:30'], ['14:00', '18:00']]
    : [['10:00', '12:00'], ['14:00', '17:00']];
  return [[], [], [], weekday, weekday, weekday, season === 'summer' ? [['09:00', '13:00']] : [['10:00', '13:00']]];
}

export function openingInfo(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Brussels', year: 'numeric', month: 'numeric', day: 'numeric',
    hour: 'numeric', minute: 'numeric', hourCycle: 'h23',
  }).formatToParts(now);
  const getPart = (name) => Number(parts.find(part => part.type === name).value);
  const year = getPart('year');
  const month = getPart('month');
  const day = getPart('day');
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  const season = seasonFor(month, day);
  const minutes = getPart('hour') * 60 + getPart('minute');
  return { year, month, day, minutes, season, weekday, intervals: weekFor(season)[weekday] };
}

export function formatIntervals(intervals) {
  return intervals.length ? intervals.map(([start, end]) => `${start}–${end}`).join(' & ') : 'Gesloten';
}

const toMinutes = (time) => {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
};

// Live status from the fixed schedule; announced exceptions are shown separately.
export function openingStatus(now = new Date()) {
  const today = openingInfo(now);
  const current = today.intervals.find(([start, end]) => toMinutes(start) <= today.minutes && today.minutes < toMinutes(end));
  if (current) return { open: true, text: `Nu open tot ${current[1]}` };
  const later = today.intervals.find(([start]) => toMinutes(start) > today.minutes);
  if (later) {
    return { open: false, nextDate: Date.UTC(today.year, today.month - 1, today.day), text: `Nu gesloten · vandaag weer open vanaf ${later[0]}` };
  }
  for (let offset = 1; offset <= 7; offset += 1) {
    const date = new Date(Date.UTC(today.year, today.month - 1, today.day + offset));
    const intervals = weekFor(seasonFor(date.getUTCMonth() + 1, date.getUTCDate()))[date.getUTCDay()];
    if (intervals.length) {
      const when = offset === 1 ? 'morgen' : dayNames[date.getUTCDay()].toLowerCase();
      return { open: false, nextDate: date.getTime(), text: `Nu gesloten · ${when} open vanaf ${intervals[0][0]}` };
    }
  }
  return { open: false, text: 'Nu gesloten' };
}

const monthNames = ['januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli', 'augustus', 'september', 'oktober', 'november', 'december'];

// Dates written in a free-text notice ("25 november", "25/11/2026", "1 tot 15
// augustus"). A date without a year is placed in the year that puts it no more
// than 60 days before the notice was last updated, so a notice edited during a
// closure keeps its year.
export function noticeDates(text, updated) {
  const updatedAt = new Date(updated);
  if (!text || !updated || Number.isNaN(updatedAt.getTime())) return [];
  const base = openingInfo(updatedAt);
  const earliest = Date.UTC(base.year, base.month - 1, base.day) - 60 * 86400000;
  const toDate = (day, month, year) => {
    const check = new Date(Date.UTC(year ? (year < 100 ? 2000 + year : year) : base.year, month - 1, day));
    // "31 november" is not a date; NaN keeps it out of every period comparison.
    if (check.getUTCMonth() !== month - 1) return NaN;
    if (year) return Date.UTC(year < 100 ? 2000 + year : year, month - 1, day);
    const date = Date.UTC(base.year, month - 1, day);
    return date < earliest ? Date.UTC(base.year + 1, month - 1, day) : date;
  };
  const yearEarlier = (date) => {
    const value = new Date(date);
    return Date.UTC(value.getUTCFullYear() - 1, value.getUTCMonth(), value.getUTCDate());
  };
  // A range that crosses the new year starts in the year before it ends.
  const toPeriod = (start, end, startHasYear) => [start > end && !startHasYear ? yearEarlier(start) : start, end];
  const monthOf = (name) => monthNames.indexOf(name.toLowerCase()) + 1;
  const validMonth = (month) => month >= 1 && month <= 12;
  const months = monthNames.join('|');
  const separator = '\\s*(?:tot(?:\\s+en\\s+met)?|t\\.e\\.m\\.|t\\/m|-|–)\\s*';
  const named = `(\\d{1,2})(?:\\s+(${months}))?(?:\\s+(\\d{4}))?`;
  const namedEnd = `(\\d{1,2})\\s+(${months})(?:\\s+(\\d{4}))?\\b`;
  // Slash or hyphen dates; '11.00u' and '10-12u' style times are not dates.
  // "11-15 uur" is a time range, not a date.
  const numeric = '(?<![\\d.:])(\\d{1,2})[/-](\\d{1,2})(?:[/-](\\d{4}|\\d{2}))?(?![\\d.:u]|\\s*u)';
  const periods = [];
  // Each entry is an inclusive [start, end] period; a single day has start === end.
  const rest = text
    .replace(new RegExp(named + separator + namedEnd, 'gi'), (_, d1, m1, y1, d2, m2, y2) => {
      const endYear = y2 ? Number(y2) : undefined;
      const start = toDate(Number(d1), m1 ? monthOf(m1) : monthOf(m2), y1 ? Number(y1) : endYear);
      periods.push(toPeriod(start, toDate(Number(d2), monthOf(m2), endYear), Boolean(y1)));
      return ' ';
    })
    .replace(new RegExp(numeric + separator + numeric, 'g'), (match, d1, m1, y1, d2, m2, y2) => {
      if (!validMonth(Number(m1)) || !validMonth(Number(m2))) return match;
      const endYear = y2 ? Number(y2) : undefined;
      const start = toDate(Number(d1), Number(m1), y1 ? Number(y1) : endYear);
      periods.push(toPeriod(start, toDate(Number(d2), Number(m2), endYear), Boolean(y1)));
      return ' ';
    })
    // "t.e.m. 3 januari" without a start: it may already apply, so it starts at -Infinity.
    .replace(new RegExp(`(?:tot(?:\\s+en\\s+met)?|t\\.e\\.m\\.|t\\/m)\\s+(?:${namedEnd}|${numeric})`, 'gi'), (match, d1, m1, y1, d2, m2, y2) => {
      const end = d1 ? toDate(Number(d1), monthOf(m1), y1 ? Number(y1) : undefined)
        : validMonth(Number(m2)) ? toDate(Number(d2), Number(m2), y2 ? Number(y2) : undefined) : NaN;
      if (Number.isNaN(end)) return match;
      periods.push([-Infinity, end]);
      return ' ';
    });
  // "25 en 26 november" or "1, 2 en 3 mei 2027" name separate days.
  for (const match of rest.matchAll(new RegExp(`((?:\\d{1,2}\\s*(?:,|en)\\s*)*\\d{1,2})\\s+(${months})(?:\\s+(\\d{4}))?\\b`, 'gi'))) {
    for (const listed of match[1].match(/\d{1,2}/g)) {
      const date = toDate(Number(listed), monthOf(match[2]), match[3] ? Number(match[3]) : undefined);
      periods.push([date, date]);
    }
  }
  for (const match of rest.matchAll(new RegExp(numeric, 'g'))) {
    if (!validMonth(Number(match[2]))) continue;
    const date = toDate(Number(match[1]), Number(match[2]), match[3] ? Number(match[3]) : undefined);
    periods.push([date, date]);
  }
  return periods.filter(([start, end]) => !Number.isNaN(start) && !Number.isNaN(end));
}

// 'none' | 'undated' | 'upcoming' | 'today' | 'between' | 'expired'
export function noticeState(text, updated, now = new Date()) {
  if (!text) return 'none';
  const periods = updated ? noticeDates(text, updated) : [];
  if (!periods.length) return 'undated';
  const { year, month, day } = openingInfo(now);
  const today = Date.UTC(year, month - 1, day);
  if (periods.some(([start, end]) => start <= today && today <= end)) return 'today';
  if (periods.every(([start]) => today < start)) return 'upcoming';
  // "vanaf 1 december" or "tot nader bericht" is open-ended; "vanaf 11.00u" is a time on the dated day.
  if (/\bvanaf\b(?!\s*\d{1,2}(?:[.:h]\d{2})?\s*(?:u\b|uur\b))(?!\s*\d{1,2}[.:h]\d{2})|tot nader bericht/i.test(text)) return 'undated';
  if (periods.every(([, end]) => end < today)) return 'expired';
  return 'between';
}

// While a notice may apply today, the status describes the normal schedule
// instead of promising that the shop is open.
const formatTime = (minutes) => `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
const regularIntervals = (date) => {
  const value = new Date(date);
  return weekFor(seasonFor(value.getUTCMonth() + 1, value.getUTCDate()))[value.getUTCDay()];
};

// Opening hours on the days a closing notice names, when the notice is clear
// enough to compute them: "gesloten" with dates, optionally "tussen 11.00u en
// 15.00u". Returns a Map of UTC day -> intervals, or null when unsure.
export function noticeOverrides(text, updated) {
  // Only plain closures are computed; any qualifier about part of the day defers to the notice.
  if (!text || !/gesloten|verlof|sluiting/i.test(text) || /\bopen\b|geopend|\bopent\b|vanaf|tot nader bericht|standaard|normaal|gewoon|uitzonderlijk|voormiddag|namiddag|ochtend|middag|avond|deels|gedeeltelijk|halve dag|vroeger|later|behalve|uitgezonderd|uitzondering/i.test(text)) return null;
  const periods = noticeDates(text, updated);
  // An open-ended closure has no first day to compute from.
  if (!periods.length || periods.some(([start]) => !Number.isFinite(start))) return null;
  // Every part of the notice that names a date must also say the shop is closed.
  const closedWords = /gesloten|verlof|sluiting/i;
  // "niet gesloten" or "geen sluiting" corrects an earlier notice; do not guess.
  if (/\b(?:niet|geen)\s+(?:\w+\s+)?(?:gesloten|sluiting|verlof)/i.test(text)) return null;
  // Each dated clause must say the shop is closed. Clauses split at commas and
  // sentence ends ("t.e.m." and "11.00u" contain dots too); a piece without a
  // date belongs to the clause before it, or to the next one at the start,
  // unless it names a day of its own.
  const clauses = [];
  let carry = '';
  for (const piece of text.split(/[;,!?\n]+|\.\s+(?=[A-Z])/)) {
    if (noticeDates(piece, updated).length) {
      clauses.push(`${carry} ${piece}`);
      carry = '';
    } else if (clauses.length && /\b(?:maandag|dinsdag|woensdag|donderdag|vrijdag|zaterdag|zondag|morgen|overmorgen)\b/i.test(piece)) {
      // "… gesloten. Donderdag gesloten." names another day without a date; do not guess which.
      return null;
    } else if (clauses.length) clauses[clauses.length - 1] += ` ${piece}`;
    else carry += ` ${piece}`;
  }
  if (!clauses.length || clauses.some(clause => !closedWords.test(clause))) return null;
  // A time window is "11.00u-15.00u", "11:00 tot 15:00" or "van 11 tot 15 uur";
  // "van 1 tot 15 augustus" is a date range, so a month may not follow.
  const months = monthNames.join('|');
  // Hours are whole numbers, never part of a date such as 25/11.
  const hour = '(?<![\\d/])(\\d{1,2})(?![\\d/])(?:[.:h](\\d{2}))?\\s*(?:uur|u)?';
  const timeWindow = new RegExp(`(?:tussen|van)\\s*${hour}\\s*(?:en|tot|-|–)\\s*${hour}(?!\\s*(?:${months})\\b)`, 'gi');
  const windows = [...text.matchAll(timeWindow)];
  const times = windows.filter(match =>
    /[.:h]\d{2}|u(?:ur)?\s*$/i.test(match[0]) && Number(match[1]) <= 24 && Number(match[3]) <= 24);
  // "van 11 tot 15" without "uur" could be anything; do not guess.
  if (windows.length !== times.length) return null;
  // Any other clock time we cannot place makes the notice too unclear to compute.
  const leftover = text.replace(timeWindow, ' ').replace(/\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?(?![\d]|\s*u)/g, ' ');
  if (/\b\d{1,2}(?:[.:h]\d{2}\s*u?|\s*u(?:ur)?)\b/i.test(leftover)) return null;
  if (times.length > 1) return null;
  // One time window with several separate dates may belong to only one of them.
  if (times.length && periods.length > 1) return null;
  const closed = times.length
    ? [Number(times[0][1]) * 60 + Number(times[0][2] || 0), Number(times[0][3]) * 60 + Number(times[0][4] || 0)]
    : null;
  if (closed && !(closed[0] < closed[1])) return null;
  const overrides = new Map();
  for (const [start, end] of periods) {
    for (let date = start; date <= end; date += 86400000) {
      const intervals = !closed ? [] : regularIntervals(date).flatMap(([open, close]) => {
        const [from, to] = [toMinutes(open), toMinutes(close)];
        return [[from, Math.min(to, closed[0])], [Math.max(from, closed[1]), to]].filter(([a, b]) => a < b);
      }).map(([a, b]) => [formatTime(a), formatTime(b)]);
      overrides.set(date, intervals);
    }
  }
  return overrides;
}

// Today's hours including a computable notice; `adjusted` marks a changed day.
export function hoursForDay(now = new Date(), notice = '', updated = '') {
  const { year, month, day, intervals } = openingInfo(now);
  const overrides = noticeOverrides(notice, updated);
  const date = Date.UTC(year, month - 1, day);
  if (overrides?.has(date)) return { intervals: overrides.get(date), adjusted: true };
  return { intervals, adjusted: false };
}

function statusWith(now, overrides) {
  const today = openingInfo(now);
  const todayDate = Date.UTC(today.year, today.month - 1, today.day);
  const intervalsOn = (date) => (overrides.has(date) ? overrides.get(date) : regularIntervals(date));
  const note = (date) => (overrides.has(date) ? ' (aangepaste uren)' : '');
  const current = intervalsOn(todayDate).find(([start, end]) => toMinutes(start) <= today.minutes && today.minutes < toMinutes(end));
  if (current) return `Nu open tot ${current[1]}${note(todayDate)}`;
  const later = intervalsOn(todayDate).find(([start]) => toMinutes(start) > today.minutes);
  if (later) return `Nu gesloten · vandaag weer open vanaf ${later[0]}${note(todayDate)}`;
  for (let offset = 1; offset <= 30; offset += 1) {
    const date = todayDate + offset * 86400000;
    const intervals = intervalsOn(date);
    if (intervals.length) {
      const value = new Date(date);
      const weekday = dayNames[value.getUTCDay()].toLowerCase();
      // From a week ahead the weekday alone is ambiguous, so add the date.
      const when = offset === 1 ? 'morgen' : offset < 7 ? weekday : `${weekday} ${value.getUTCDate()} ${monthNames[value.getUTCMonth()]}`;
      if (overrides.has(date) && intervals.length > 1) return `Nu gesloten · ${when} open ${formatIntervals(intervals).replace(' & ', ' en ')} (aangepaste uren)`;
      return `Nu gesloten · ${when} open vanaf ${intervals[0][0]}${note(date)}`;
    }
  }
  return 'Nu gesloten · zie mededeling';
}

export function displayStatus(now = new Date(), notice = '', updated = '') {
  const status = openingStatus(now);
  const normal = { state: status.open ? 'open' : 'closed', text: status.text };
  if (!notice) return normal;
  const state = noticeState(notice, updated, now);
  if (state === 'expired' || state === 'none') return normal;
  const overrides = noticeOverrides(notice, updated);
  if (overrides) {
    const text = statusWith(now, overrides);
    return { state: text.includes('aangepaste uren') ? 'notice' : (text.startsWith('Nu open') ? 'open' : 'closed'), text };
  }
  if (state === 'today' || state === 'undated') return { state: 'notice', text: `${status.text.replace(/^Nu /, 'Normaal ')} · zie mededeling` };
  const covered = (date) => noticeDates(notice, updated).some(([start, end]) => start <= date && date <= end);
  if (status.open || !status.nextDate || !covered(status.nextDate)) return normal;
  const { year, month, day } = openingInfo(now);
  const offset = Math.round((status.nextDate - Date.UTC(year, month - 1, day)) / 86400000);
  const when = offset === 0 ? 'vandaag' : offset === 1 ? 'morgen' : dayNames[new Date(status.nextDate).getUTCDay()].toLowerCase();
  return { state: 'notice', text: `Nu gesloten · ${when} afwijkende uren (zie mededeling)` };
}
