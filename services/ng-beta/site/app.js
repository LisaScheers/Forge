import { openingInfo, displayStatus, noticeState, noticeOverrides, hoursForDay, formatIntervals } from './hours.js?v=eb96bd57a9';

const header = document.querySelector('.site-header');
const menuButton = document.querySelector('.menu-toggle');
const navigation = document.querySelector('#main-nav');
menuButton.hidden = false;

function closeMenu(returnFocus = false) {
  document.documentElement.classList.remove('menu-covers-bar');
  menuButton.setAttribute('aria-expanded', 'false');
  navigation.dataset.open = 'false';
  if (returnFocus) menuButton.focus();
}

// Fit the open menu between the header and the fixed contact bar; it scrolls inside.
function fitMenu() {
  if (navigation.dataset.open !== 'true') return;
  // Back on a desktop layout the menu is a normal row again.
  if (getComputedStyle(menuButton).display === 'none') {
    closeMenu();
    navigation.style.maxHeight = '';
    return;
  }
  const bar = document.querySelector('.mobile-contact');
  document.documentElement.classList.remove('menu-covers-bar');
  const barHeight = bar && getComputedStyle(bar).display !== 'none' ? bar.offsetHeight : 0;
  const room = innerHeight - header.getBoundingClientRect().bottom - 8;
  // When the menu does not fit above the contact bar (short screens, high zoom,
  // a long shop notice), it covers the bar; the menu holds the phone and route too.
  const coverBar = barHeight && navigation.scrollHeight > room - barHeight;
  document.documentElement.classList.toggle('menu-covers-bar', Boolean(coverBar));
  navigation.style.maxHeight = `${Math.max(0, coverBar ? room : room - barHeight)}px`;
}
menuButton.addEventListener('click', () => {
  const open = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(open));
  navigation.dataset.open = String(open);
  fitMenu();
});
window.addEventListener('resize', fitMenu);
// The sticky header moves up as the notice scrolls away; the menu gets that room.
window.addEventListener('scroll', fitMenu, { passive: true });
navigation.addEventListener('click', event => {
  if (event.target.closest('a')) closeMenu();
});
// Keyboard users who tab past the last link should not land behind the open menu.
header.addEventListener('focusout', event => {
  if (!header.contains(event.relatedTarget)) closeMenu();
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && menuButton.getAttribute('aria-expanded') === 'true') closeMenu(true);
});
document.addEventListener('click', event => {
  if (!event.target.closest('.site-header')) closeMenu();
});
// The head script falls back to the plain link list if this never runs.
document.documentElement.classList.add('js', 'menu-ready');
if (navigator.clipboard) document.documentElement.classList.add('clip');
// Keep keyboard focus clear of the fixed contact bar on phones and the sticky header.
const contactBar = document.querySelector('.mobile-contact');
document.addEventListener('focusin', event => {
  // Only keyboard focus; moving the page under a pointer could swallow the click.
  if (!event.target.matches(':focus-visible') || event.target.matches('.skip-link') || header.contains(event.target) || contactBar?.contains(event.target)) return;
  const rect = event.target.getBoundingClientRect();
  const barVisible = contactBar && getComputedStyle(contactBar).display !== 'none';
  const barTop = barVisible ? contactBar.getBoundingClientRect().top : innerHeight;
  const headerBottom = header.getBoundingClientRect().bottom;
  if (rect.bottom > barTop - 8) window.scrollBy({ top: rect.bottom - barTop + 16, behavior: 'instant' });
  else if (rect.top < headerBottom + 8) window.scrollBy({ top: rect.top - headerBottom - 16, behavior: 'instant' });
});

const noticeTexts = [...document.querySelectorAll('[data-shop-notice-text]')];
const noticeBlocks = [...document.querySelectorAll('[data-shop-notice]')];
const noticeText = () => noticeTexts[0]?.textContent.trim() || '';
const noticeUpdated = () => noticeBlocks[0]?.dataset.noticeUpdated || '';
const currentNotice = () => (noticeBlocks[0]?.hidden ? '' : noticeText());
function showNotice() {
  const visible = !['none', 'expired'].includes(noticeState(noticeText(), noticeUpdated()));
  noticeBlocks.forEach(element => { element.hidden = !visible; });
  // The pre-paint script may have hidden an expired build-time notice.
  if (visible) document.documentElement.classList.remove('notice-expired');
}

let selectedSeason = openingInfo().season;
let seasonWasSelected = false;
const seasonButtons = [...document.querySelectorAll('[data-season]')];
function renderHours() {
  const today = openingInfo();
  if (!seasonWasSelected) selectedSeason = today.season;
  showNotice();
  const status = displayStatus(new Date(), currentNotice(), noticeUpdated());
  const day = hoursForDay(new Date(), currentNotice(), noticeUpdated());
  const unclear = !day.adjusted && ['today', 'undated'].includes(noticeState(currentNotice(), noticeUpdated()));
  const label = day.adjusted ? 'Vandaag (aangepaste uren)' : unclear ? 'Normaal rooster vandaag' : 'Vandaag';
  document.querySelectorAll('[data-today]').forEach(element => {
    element.textContent = `${label}: ${formatIntervals(day.intervals).toLowerCase()}`;
  });
  document.querySelectorAll('[data-status]').forEach(element => { element.textContent = status.text; });
  document.querySelectorAll('[data-status-dot]').forEach(element => { element.dataset.state = status.state; });
  seasonButtons.forEach(button => {
    button.setAttribute('aria-pressed', String(button.dataset.season === selectedSeason));
  });
  // Days in the coming week that a clear notice changes, keyed by weekday.
  const overrides = noticeOverrides(currentNotice(), noticeUpdated()) ?? new Map();
  const todayDate = Date.UTC(today.year, today.month - 1, today.day);
  const exceptions = new Map([...overrides].filter(([date]) => date >= todayDate && date < todayDate + 7 * 86400000)
    .map(([date, intervals]) => {
      const value = new Date(date);
      return [value.getUTCDay(), { label: `Aangepast op ${value.getUTCDate()}/${value.getUTCMonth() + 1}: `, intervals }];
    }));
  document.querySelectorAll('.hours-exception, .hours-normal-label').forEach(element => element.remove());
  document.querySelectorAll('[data-exception]').forEach(cell => delete cell.dataset.exception);
  document.querySelectorAll('[data-hours-season]').forEach(schedule => {
    schedule.hidden = schedule.dataset.hoursSeason !== selectedSeason;
    if (schedule.dataset.hoursSeason === today.season) {
      schedule.querySelectorAll('[data-day]').forEach(row => {
        const exception = exceptions.get(Number(row.dataset.day));
        if (!exception) return;
        // The adjusted hours come first; the regular hours stay below, labelled as such.
        const cell = row.querySelector('td');
        const note = document.createElement('span');
        note.className = 'hours-exception';
        // Each interval stays on one line, like the regular hours.
        note.append(exception.label, ...(exception.intervals.length ? exception.intervals.flatMap(([start, end], index) => {
          const slot = document.createElement('span');
          slot.className = 'hours-slot';
          slot.textContent = `${start}–${end}`;
          return index ? [' & ', slot] : [slot];
        }) : ['gesloten']));
        const label = document.createElement('span');
        label.className = 'hours-normal-label';
        label.textContent = 'Normaal: ';
        cell.dataset.exception = 'true';
        cell.prepend(note, label);
      });
    }
    schedule.querySelectorAll('[data-day]').forEach(row => {
      const current = Number(row.dataset.day) === today.weekday && selectedSeason === today.season;
      row.dataset.current = String(current);
      if (current) row.querySelector('th').setAttribute('aria-current', 'date');
      else row.querySelector('th').removeAttribute('aria-current');
    });
  });
}
seasonButtons.forEach(button => {
  button.addEventListener('click', () => {
    seasonWasSelected = true;
    selectedSeason = button.dataset.season;
    renderHours();
  });
});
renderHours();
const seasonSwitch = document.querySelector('.season-switch');
if (seasonSwitch) seasonSwitch.hidden = false;
const hoursCard = document.querySelector('.hours-card');
if (hoursCard) hoursCard.dataset.enhanced = 'true';
// The static fallback is taller; restore the requested anchor after enhancement.
window.addEventListener('load', () => {
  requestAnimationFrame(() => {
    document.getElementById(location.hash.slice(1))?.scrollIntoView({ block: 'start', behavior: 'instant' });
  });
}, { once: true });

// The build bakes in the shop notice from the Firestore document the previous
// website used; refresh it here so a newer notice appears without a rebuild.
// The markup is rendered as plain text only.
// It waits for the page to load, so first paint needs no third-party request.
const refreshNotice = () => fetch('https://firestore.googleapis.com/v1/projects/ng-pool-site/databases/(default)/documents/notes/1', { signal: AbortSignal.timeout(8000), referrerPolicy: 'no-referrer' })
  .then(response => (response.ok ? response.json() : null))
  .then(data => {
    if (!data) return;
    const markup = data.fields?.content?.stringValue || '';
    // Paragraphs and line breaks become newlines: hours.js reads each line as its own clause.
    const spaced = markup.replace(/<\/(p|div|li|h\d)>|<br\s*\/?>/gi, '$&\n');
    const notice = new DOMParser().parseFromString(spaced, 'text/html').body.textContent
      .replace(/[^\S\n]+/g, ' ').replace(/ *\n\s*/g, '\n').trim();
    noticeTexts.forEach(element => { element.textContent = notice; });
    noticeBlocks.forEach(element => { element.dataset.noticeUpdated = data.updateTime || ''; });
    renderHours();
  })
  .catch(() => {});
if (document.readyState === 'complete') refreshNotice();
else window.addEventListener('load', refreshNotice, { once: true });
// Refresh the status every minute without interrupting a selected season.
setInterval(renderHours, 60_000);

// Copy buttons help visitors whose browser has no mail app configured.
if (navigator.clipboard) {
  document.querySelectorAll('[data-copy-email]').forEach(button => {
    button.hidden = false;
    button.addEventListener('click', async () => {
      const feedback = button.parentElement.querySelector('[data-copy-feedback]') ?? document.querySelector('[data-copy-feedback]');
      feedback.textContent = '';
      await new Promise(resolve => setTimeout(resolve, 50));
      try {
        await navigator.clipboard.writeText(button.dataset.copyEmail);
        feedback.textContent = 'E-mailadres gekopieerd.';
      } catch {
        feedback.textContent = 'Kopiëren lukte niet. Ons adres is info@ngpoolservice.be.';
      }
    });
  });
}
document.querySelector('#copyright-year').textContent = new Intl.DateTimeFormat('nl-BE', { year: 'numeric', timeZone: 'Europe/Brussels' }).format(new Date());
