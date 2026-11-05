const $ = (id) => document.getElementById(id);
const number = new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 });
const compact = new Intl.NumberFormat(undefined, { notation: 'compact', maximumFractionDigits: 1 });
const format = (value, short = false) => value == null ? '—' : (short ? compact : number).format(value);
const date = (value) => value ? new Date(value.includes('T') ? value : value.replace(' ', 'T') + 'Z').toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';
const state = { offset: 0, selected: null, conversation: null, mode: 'messages', generation: 0, selectedGeneration: 0, messages: [] };

function el(tag, className = '', text) {
  const node = document.createElement(tag);
  node.className = className;
  if (text !== undefined) node.textContent = String(text);
  return node;
}

function svg(tag, attributes = {}) {
  const node = document.createElementNS('http://www.w3.org/2000/svg', tag);
  for (const [key, value] of Object.entries(attributes)) node.setAttribute(key, value);
  return node;
}

async function api(url) {
  const response = await fetch(url, { credentials: 'same-origin', cache: 'no-store' });
  if (response.status === 401) {
    location.assign('/');
    throw new Error('Please sign in again.');
  }
  if (!response.ok) throw new Error('The archive is unavailable. Please try again.');
  return response.json();
}

function fail(error) {
  $('notice').textContent = error.message || 'Could not load the archive.';
  $('notice').hidden = false;
}

function query(extra = {}) {
  return new URLSearchParams({ days: $('days').value, model: $('model').value, client: $('client').value, q: $('search').value.trim(), status: $('status').value, ...extra });
}

function metric(label, value, note) {
  const box = el('div', 'metric');
  box.append(el('span', '', label), el('strong', '', format(value)), el('small', '', note));
  return box;
}

function empty(text) { return el('div', 'empty-text', text); }

function tableRow(values) {
  const row = el('tr');
  for (const value of values) row.append(el('td', '', value));
  return row;
}

function renderActivity(points) {
  const root = $('activity');
  root.replaceChildren();
  if (!points.length) { root.append(empty('No token activity for these filters.')); return; }
  const byDay = new Map(points.map((point) => [point.day, point]));
  const first = new Date(points[0].day + 'T00:00:00Z');
  const last = new Date(points.at(-1).day + 'T00:00:00Z');
  const days = [];
  for (let time = first.getTime(); time <= last.getTime(); time += 86400000) {
    const day = new Date(time).toISOString().slice(0, 10);
    days.push(byDay.get(day) || { day, input_tokens: 0, output_tokens: 0, cached_tokens: 0 });
  }
  const width = 660, height = 195, left = 48, bottom = 29, top = 15;
  const chart = svg('svg', { viewBox: `0 0 ${width} ${height}`, role: 'img', 'aria-label': 'Daily token counts, cached input shown separately from uncached input and output' });
  const max = Math.max(1, ...days.map((point) => (point.input_tokens || 0) + (point.output_tokens || 0)));
  const scale = (height - top - bottom) / max;
  for (let index = 0; index <= 3; index++) {
    const y = top + (height - top - bottom) * index / 3;
    chart.append(svg('line', { x1: left, x2: width - 8, y1: y, y2: y, class: 'chart-grid' }));
    const label = svg('text', { x: left - 9, y: y + 3, 'text-anchor': 'end', class: 'chart-label' });
    label.textContent = format(max * (1 - index / 3), true);
    chart.append(label);
  }
  const step = (width - left - 15) / days.length;
  const barWidth = Math.min(38, step * .65);
  days.forEach((point, index) => {
    const x = left + step * index + (step - barWidth) / 2;
    const cached = Math.min(point.input_tokens || 0, point.cached_tokens || 0);
    const portions = [[Math.max(0, (point.input_tokens || 0) - cached), 'chart-input'], [cached, 'chart-cached'], [point.output_tokens || 0, 'chart-output']];
    let y = height - bottom;
    for (const [count, className] of portions) {
      const barHeight = count * scale;
      y -= barHeight;
      const rect = svg('rect', { x, y, width: barWidth, height: barHeight, class: className });
      const title = svg('title'); title.textContent = `${point.day}: ${format(count)} tokens`; rect.append(title); chart.append(rect);
    }
    if (days.length <= 10 || index % Math.ceil(days.length / 7) === 0 || index === days.length - 1) {
      const label = svg('text', { x: x + barWidth / 2, y: height - 8, 'text-anchor': 'middle', class: 'chart-label' });
      label.textContent = new Date(point.day + 'T12:00:00Z').toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
      chart.append(label);
    }
  });
  root.append(chart);
}

function renderAnalytics(data) {
  const totals = data.totals;
  $('metrics').replaceChildren(
    metric('Reported tokens', totals.total_tokens, `${format(totals.conversations || 0)} conversations · input + output`),
    metric('Requests / responses', totals.requests, `${format(totals.errors || 0)} errors · includes upstream attempts`),
    metric('Cached input', totals.cached_tokens, totals.input_tokens ? `${((totals.cached_tokens || 0) / totals.input_tokens * 100).toFixed(1)}% of input tokens` : 'A subset of input tokens'),
    metric('Reasoning tokens', totals.reasoning_tokens, 'A subset of output tokens'),
  );
  renderActivity(data.timeline);
  $('chart-period').textContent = $('days').selectedOptions[0].textContent;
  $('coverage').textContent = totals.missing_usage ? `Usage was not reported for ${format(totals.missing_usage)} responses. Unknown counts are left empty.` : 'Usage is available for every response in this view.';
  const clients = $('clients'); clients.replaceChildren();
  const max = Math.max(1, ...data.clients.map((item) => item.total_tokens || 0));
  for (const client of data.clients) {
    const item = el('div', 'client-item'), line = el('div', 'client-line');
    line.append(el('strong', '', client.client), el('span', '', `${format(client.total_tokens, true)} tokens · ${format(client.requests)} req`));
    const track = svg('svg', { viewBox: '0 0 100 5', preserveAspectRatio: 'none', class: 'client-track', 'aria-hidden': 'true' });
    track.append(svg('rect', { width: 100, height: 5, rx: 1, class: 'track' }), svg('rect', { width: (client.total_tokens || 0) / max * 100, height: 5, rx: 1 }));
    item.append(line, track); clients.append(item);
  }
  if (!data.clients.length) clients.append(empty('No clients in this view.'));
  $('model-count').textContent = `${data.models.length} models`;
  $('models').replaceChildren(...data.models.map((model) => tableRow([model.model, model.provider, format(model.requests), format(model.input_tokens), format(model.output_tokens), format(model.cached_tokens), format(model.total_tokens)])));
  const categories = $('categories'); categories.replaceChildren();
  for (const item of data.categories) {
    const row = el('div', 'counter-row'); row.append(el('span', '', item.name), el('strong', '', format(item.tokens))); categories.append(row);
  }
  if (!data.categories.length) categories.append(empty('No reported counters yet.'));
}

function conversationItem(item, recent = false) {
  if (recent) {
    const link = el('a', 'recent-item'); link.href = `#conversations/${item.id}`;
    const meta = el('span', 'recent-meta'); meta.append(el('span', '', item.models), el('span', '', date(item.updated_at)));
    link.append(el('span', 'recent-title', item.title), meta); return link;
  }
  const button = el('button', 'conversation-item' + (state.selected === item.id ? ' selected' : ''));
  button.dataset.id = item.id;
  const meta = el('span', 'meta'); meta.append(el('span', 'tag', item.models), el('span', '', date(item.updated_at)));
  button.append(el('span', 'title', item.title), meta,
    el('span', 'stats', `${format(item.requests)} responses · ${format(item.total_tokens, true)} tokens${item.grouping === 'request' ? ' · individual request' : ''}${item.errors ? ' · error' : ''}`));
  button.addEventListener('click', () => { location.hash = `conversations/${item.id}`; });
  return button;
}

async function reloadData(append = false) {
  const generation = ++state.generation;
  const offset = append ? state.offset : 0;
  try {
    const [list, analytics] = await Promise.all([
      api('/api/conversations?' + query({ offset })),
      append ? Promise.resolve(null) : api('/api/analytics?' + query()),
    ]);
    if (generation !== state.generation) return;
    if (!append) $('conversation-items').replaceChildren();
    $('conversation-items').append(...list.items.map((item) => conversationItem(item)));
    if (!append && !list.items.length) $('conversation-items').append(empty('No conversations match these filters.'));
    $('list-count').textContent = `${format(list.total)} conversations`;
    $('nav-count').textContent = format(list.total, true);
    state.offset = offset + list.items.length;
    $('load-more').hidden = !list.has_more;
    if (analytics) {
      renderAnalytics(analytics);
      $('recent').replaceChildren(...list.items.slice(0, 5).map((item) => conversationItem(item, true)));
      if (!list.items.length) $('recent').append(empty('No conversations match these filters.'));
    }
  } catch (error) { fail(error); }
}

function renderMessage(message) {
  const tool = ['tool', 'system', 'developer'].includes(message.role) || ['tool_call', 'tool_result', 'reasoning'].includes(message.kind);
  const article = el('article', 'message' + (tool ? ' tool' : '')); article.dataset.role = message.role;
  const heading = el('div', 'message-head');
  const label = message.kind === 'tool_call' ? `Tool call${message.tool ? ' · ' + message.tool : ''}` : message.kind === 'tool_result' ? 'Tool result' : message.kind === 'reasoning' ? 'Reasoning' : message.role[0].toUpperCase() + message.role.slice(1);
  heading.append(el('strong', '', label));
  if (message.request_id) {
    const inspect = el('button', '', 'Inspect request ↗'); inspect.addEventListener('click', () => showRequest(message.request_id)); heading.append(inspect);
  }
  article.append(heading);
  const content = el('pre', 'message-content', message.text);
  if (tool) { const details = el('details'); details.append(el('summary', '', `${label} · ${format(message.text.length)} characters`), content); article.append(details); }
  else article.append(content);
  return article;
}

function renderReader() {
  const data = state.conversation;
  if (!data) return;
  const root = $('reader'); root.replaceChildren();
  const header = el('header', 'reader-header'); header.append(el('h2', '', data.title));
  const summary = el('div', 'reader-summary');
  const known = data.requests.filter((item) => item.total_tokens != null);
  summary.append(el('span', '', `${format(data.total_messages)} messages`), el('span', '', `${format(data.requests.length)} responses`),
    el('span', '', known.length ? `${format(known.reduce((sum, item) => sum + item.total_tokens, 0))} reported tokens` : 'Usage unreported'),
    el('span', '', data.grouping === 'session' ? 'Grouped by session ID' : 'No conversation ID · individual request'));
  header.append(summary); root.append(header);
  const tabs = el('div', 'reader-tabs');
  for (const [id, label] of [['messages', 'Conversation'], ['requests', 'Requests & usage']]) {
    const button = el('button', state.mode === id ? 'active' : '', label); button.addEventListener('click', () => { state.mode = id; renderReader(); }); tabs.append(button);
  }
  root.append(tabs);
  if (state.mode === 'requests') {
    for (const request of data.requests) {
      const row = el('button', 'request-row'), left = el('span');
      const name = el('strong'); name.append(el('span', 'status-badge ' + request.status, request.status), document.createTextNode(request.model));
      left.append(name, el('small', '', `${date(request.started_at)} · ${request.provider} · ${request.client}`));
      row.append(left, el('span', 'request-count', `${format(request.total_tokens)} tokens ↗`));
      row.addEventListener('click', () => showRequest(request.id)); root.append(row);
    }
    return;
  }
  const messages = el('div', 'messages');
  if (data.before != null) {
    const older = el('button', 'older-button', 'Load earlier messages');
    older.addEventListener('click', async () => {
      older.disabled = true;
      try {
        const previous = await api(`/api/conversations/${data.id}?before=${data.before}`);
        if (state.selected !== data.id) return;
        state.messages = [...previous.messages, ...state.messages];
        state.conversation.before = previous.before; renderReader();
      } catch (error) { older.disabled = false; fail(error); }
    });
    messages.append(older);
  }
  messages.append(...state.messages.map(renderMessage));
  if (!state.messages.length) messages.append(empty('No readable message content was returned. Inspect the request or download its full capture.'));
  root.append(messages);
}

async function loadSelection(identity) {
  const generation = ++state.selectedGeneration;
  state.selected = identity; state.mode = 'messages';
  $('conversations').classList.add('has-selection');
  for (const item of document.querySelectorAll('.conversation-item')) item.classList.toggle('selected', item.dataset.id === identity);
  $('reader').replaceChildren(el('div', 'reader-loading', 'Loading conversation…'));
  try {
    const data = await api(`/api/conversations/${identity}`);
    if (generation !== state.selectedGeneration) return;
    state.conversation = data; state.messages = data.messages; renderReader();
  } catch (error) { fail(error); $('reader').replaceChildren(empty(error.message)); }
}

async function showRequest(identity) {
  try {
    const data = await api(`/api/requests/${identity}`);
    $('request-model').textContent = data.model;
    const body = el('div', 'dialog-body'), facts = el('div', 'request-facts');
    for (const [label, value] of [['Status', data.status], ['Client', data.client], ['Started', date(data.started_at)], ['Provider', data.provider], ['Input tokens', format(data.input_tokens)], ['Output tokens', format(data.output_tokens)], ['Cached input', format(data.cached_tokens)], ['Reasoning tokens', format(data.reasoning_tokens)]]) {
      const fact = el('div'); fact.append(el('span', '', label), el('strong', '', value)); facts.append(fact);
    }
    body.append(facts, el('h3', 'detail-heading', 'Every reported counter'));
    const counters = el('div', 'request-counters');
    for (const [key, value] of Object.entries(data.tokens).sort(([left], [right]) => left.localeCompare(right))) {
      const row = el('div', 'counter-row'); row.append(el('span', '', key), el('strong', '', format(value))); counters.append(row);
    }
    if (!Object.keys(data.tokens).length) counters.append(empty('The provider did not report usage for this response.'));
    body.append(counters);
    if (data.error) body.append(el('h3', 'detail-heading', 'Error'), el('pre', 'message-content', data.error));
    for (const [title, messages] of [['Input context', data.input], ['Response', data.output]]) {
      body.append(el('h3', 'detail-heading', title));
      const content = el('div', 'detail-messages'); content.append(...messages.map(renderMessage));
      if (!messages.length) content.append(empty('No message content. The wire capture remains available.'));
      body.append(content);
    }
    const download = el('a', 'raw-link', 'Download full wire capture ↓'); download.href = `/api/captures/${data.capture_id}/raw`;
    body.append(download, el('p', 'raw-notice', 'Includes complete request context, responses, and provider events.'));
    $('request-content').replaceChildren(body);
    $('request-dialog').showModal();
  } catch (error) { fail(error); }
}

async function refreshStatus() {
  try {
    const data = await api('/api/status');
    for (const [id, options, label] of [['model', data.models, 'All models'], ['client', data.clients, 'All clients']]) {
      const selected = $(id).value;
      const initial = el('option', '', label); initial.value = '';
      $(id).replaceChildren(initial, ...options.map((value) => { const option = el('option', '', value); option.value = value; return option; }));
      $(id).value = selected;
    }
    $('sync-state').textContent = data.sync_error ? 'Capture sync delayed' : data.pending ? `Indexing ${data.pending} captures` : 'Archive connected';
    $('archive-summary').textContent = `${format(data.captures)} captures · ${format(data.bytes / 1048576)} MB archived · ${data.last_sync ? 'Synced ' + date(data.last_sync) : 'Initial sync in progress'}`;
    if (data.sync_error) fail(new Error('Capture sync is delayed. Saved conversations are still available.'));
    else $('notice').hidden = true;
  } catch (error) { fail(error); }
}

function route() {
  const match = location.hash.match(/^#conversations(?:\/([a-f0-9]{64}))?$/);
  $('overview').hidden = !!match; $('conversations').hidden = !match;
  $('nav-overview').classList.toggle('active', !match); $('nav-conversations').classList.toggle('active', !!match);
  $('page-title').textContent = match ? 'Conversations' : 'Overview';
  document.title = `${match ? 'Conversations' : 'Overview'} · AI Archive`;
  if (match?.[1] && match[1] !== state.selected) loadSelection(match[1]);
}

let searchTimer;
$('search').addEventListener('input', () => { clearTimeout(searchTimer); searchTimer = setTimeout(() => reloadData(), 300); });
for (const id of ['days', 'model', 'client', 'status']) $(id).addEventListener('change', () => reloadData());
$('load-more').addEventListener('click', () => reloadData(true));
$('refresh').addEventListener('click', async () => { await refreshStatus(); await reloadData(); });
$('close-dialog').addEventListener('click', () => $('request-dialog').close());
$('request-dialog').addEventListener('click', (event) => { if (event.target === $('request-dialog')) $('request-dialog').close(); });
addEventListener('hashchange', route);
addEventListener('keydown', (event) => {
  if (event.key === '/' && !['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) { event.preventDefault(); $('search').focus(); }
});
route();
await refreshStatus();
await reloadData();
setInterval(refreshStatus, 30000);
