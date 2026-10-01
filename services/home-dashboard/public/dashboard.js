"use strict";

// Icons stay local; loading a private service never contacts an icon CDN.
const icons = {
  spark: '<path d="M12 2v20M2 12h20M5 5l14 14M19 5 5 19"/>',
  code: '<circle cx="6" cy="4" r="2"/><circle cx="6" cy="20" r="2"/><circle cx="18" cy="6" r="2"/><path d="M6 6v12m12-10v2c0 4-12 2-12 6"/>',
  butterfly: '<path d="M12 12C9 6 2 3 3 9s5 5 9 3Zm0 0c3-6 10-9 9-3s-5 5-9 3Zm0 0c-7 0-8 7-4 7 3 0 4-4 4-7Zm0 0c7 0 8 7 4 7-3 0-4-4-4-7Z"/>',
  chat: '<path d="M21 11a9 9 0 0 1-9 9H4l-3 2 2-7a9 9 0 1 1 18-4Z"/><path d="M7 10h10M7 14h6"/>',
  play: '<path d="m12 3 10 18H2L12 3Z"/><path d="m12 9 5 9H7l5-9Z"/>',
  ticket: '<path d="M3 6h18v4a2 2 0 0 0 0 4v4H3v-4a2 2 0 0 0 0-4V6Z"/><path d="M15 6v2m0 3v2m0 3v2"/>',
  home: '<path d="m2 11 10-9 10 9M5 9v12h14V9M12 21v-9m0 4 4-3m-4 0-4-3"/><circle cx="8" cy="10" r="1"/><circle cx="16" cy="13" r="1"/>',
  popcorn: '<path d="m5 10 2 12h10l2-12H5Zm4 0 1 12m5-12-1 12"/><path d="M5 10a3 3 0 0 1-1-5 3 3 0 0 1 5-2 4 4 0 0 1 7 0 3 3 0 0 1 4 5l-1 2"/>',
  radar: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><path d="m12 12 7-7"/><circle cx="12" cy="12" r="1"/>',
  film: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M7 3v18M17 3v18M3 8h4m10 0h4M3 16h4m10 0h4M7 12h10"/>',
  search: '<circle cx="10" cy="10" r="7"/><path d="m15 15 6 6"/>',
  download: '<path d="M12 2v13m-5-5 5 5 5-5M3 15v6h18v-6"/>',
  shield: '<path d="m12 2 9 4v6c0 6-9 10-9 10S3 18 3 12V6l9-4Z"/><path d="m8 12 3 3 5-6"/>',
  document: '<path d="M5 2h10l4 4v16H5V2Zm10 0v5h4M8 11h8M8 15h8M8 19h4"/>',
  bell: '<path d="M5 9a7 7 0 0 1 14 0v6l2 3H3l2-3V9Zm4 12h6"/>',
  chart: '<path d="M3 3v18h18M7 16v-5m5 5V6m5 10v-7"/>',
  heart: '<path d="M12 21 3 12C-2 6 6 0 12 6c6-6 14 0 9 6l-9 9Z"/><path d="M4 12h4l2-4 4 8 2-4h4"/>',
  flame: '<path d="M12 2c2 6 7 7 7 13a7 7 0 0 1-14 0c0-3 1-5 3-7 0 4 2 4 2 4s4-4 2-10Z"/>',
  mail: '<rect x="2" y="4" width="20" height="16" rx="3"/><path d="m3 6 9 7 9-7"/>',
  game: '<path d="M6 7h12c4 0 6 13 2 13l-5-4H9l-5 4C0 20 2 7 6 7Z"/><path d="M6 10v6m-3-3h6M16 11h.01M19 14h.01"/>',
  server: '<rect x="3" y="3" width="18" height="7" rx="2"/><rect x="3" y="14" width="18" height="7" rx="2"/><path d="M7 6.5h.01M7 17.5h.01M12 6.5h5m-5 11h5"/>'
};
const labels = {up: "Healthy", down: "Unavailable", pending: "Retrying", unknown: "Unknown", maintenance: "Maintenance", paused: "Paused"};
const groups = ["Social & publishing", "Home & media", "Tools & monitoring", "Games", "Infrastructure"];
let services = [];
let issuesOnly = false;
let refreshing = false;
let generated = null;
let signedIn = false;
const search = document.querySelector("#search");

function node(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}

function status(value) {
  const element = node("span", `status ${value}`);
  element.append(node("span", "dot"), node("span", "", labels[value] || "Unknown"));
  return element;
}

function age(timestamp) {
  if (!timestamp) return "No measurement yet";
  const seconds = Math.max(0, Math.floor(Date.now() / 1000 - timestamp));
  if (seconds < 60) return "Just checked";
  if (seconds < 3600) return `Checked ${Math.floor(seconds / 60)}m ago`;
  return `Checked ${Math.floor(seconds / 3600)}h ago`;
}

function card(service) {
  const element = node("article", "card");
  const top = node("div", "card-top");
  const icon = node("span", "icon");
  icon.setAttribute("aria-hidden", "true");
  // Only constant SVG markup is inserted here, never API content.
  icon.innerHTML = `<svg viewBox="0 0 24 24">${icons[service.icon] || icons.server}</svg>`;
  top.append(icon);
  if (service.url) top.append(node("span", "arrow", "↗"));
  const title = node("h3");
  if (service.url) {
    const link = node("a", "", service.name);
    link.href = service.url;
    title.append(link);
  } else title.textContent = service.name;
  element.append(top, title, node("p", "", service.description));
  if (service.connection) {
    const copy = node("button", "copy", service.connection + " ⧉");
    copy.type = "button";
    copy.setAttribute("aria-label", "Copy server address for " + service.name);
    copy.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(service.connection);
        copy.textContent = "Copied!";
        setTimeout(() => { copy.textContent = service.connection + " ⧉"; }, 2000);
      } catch { copy.textContent = service.connection; }
    });
    element.append(copy);
  }
  const bottom = node("div", "card-bottom");
  bottom.append(status(service.status), node("span", "access", service.local ? "Home / Tailscale" : service.public ? "Public" : "Private"));
  element.append(bottom);
  if (service.checks.length) {
    const details = node("details", "check-details");
    details.dataset.service = service.id;
    details.append(node("summary", "", "Check details"));
    for (const check of service.checks) {
      const row = node("div", "check-row");
      row.append(node("span", "", check.name), status(check.status));
      details.append(row, node("div", "check-time", `${check.kind} · ${age(check.checked)}${check.latency !== null ? ` · ${check.latency} ms` : ""}`));
    }
    element.append(details);
  }
  return element;
}

function render() {
  const container = document.querySelector("#services");
  const expanded = new Set([...container.querySelectorAll("details[open]")].map(detail => detail.dataset.service));
  const query = search.value.trim().toLocaleLowerCase();
  const filtered = services.filter(service => (!issuesOnly || service.status !== "up") && `${service.name} ${service.description} ${service.group}`.toLocaleLowerCase().includes(query));
  document.querySelector("#total").textContent = services.length;
  document.querySelector("#issue-count").textContent = services.filter(service => service.status !== "up").length;
  const fragment = document.createDocumentFragment();
  for (const group of groups) {
    const entries = filtered.filter(service => service.group === group);
    if (!entries.length) continue;
    const section = node("section", "group" + (group === "Infrastructure" ? " infrastructure" : ""));
    const heading = node("h2", "", group);
    heading.append(node("span", "", String(entries.length).padStart(2, "0")));
    const grid = node("div", "grid");
    entries.forEach(service => grid.append(card(service)));
    section.append(heading, grid);
    fragment.append(section);
  }
  if (!filtered.length) {
    const empty = node("div", "empty");
    empty.append(node("h2", "", query ? "No services found" : "All clear."), node("p", "", query ? "Try another name or category." : "Every visible service is healthy."));
    fragment.append(empty);
  }
  container.replaceChildren(fragment);
  for (const detail of container.querySelectorAll("details")) detail.open = expanded.has(detail.dataset.service);
  document.querySelector("#updated").textContent = generated ? `Status refreshed ${new Date(generated * 1000).toLocaleTimeString([], {hour: "2-digit", minute: "2-digit"})} · checks every 30–60s` : "Status not available";
}

async function request(route) {
  const response = await fetch(route, {credentials: "same-origin", cache: "no-store", redirect: "error"});
  if (!response.ok) throw new Error(String(response.status));
  return response.json();
}

async function refresh() {
  if (refreshing) return;
  refreshing = true;
  const notice = document.querySelector("#notice");
  try {
    // Always get the public view first; a lost session immediately clears private data.
    const publicView = await request("/api/public");
    let view = publicView;
    let authenticationFailed = false;
    try { view = await request("/api/private"); }
    catch (error) { authenticationFailed = error.message !== "401" && error.message !== "403"; }
    signedIn = Boolean(view.user);
    services = view.services;
    generated = view.generated;
    document.querySelector("#user").textContent = view.user || "";
    const auth = document.querySelector("#auth");
    auth.href = signedIn ? "/outpost.goauthentik.io/sign_out" : "/login";
    auth.textContent = signedIn ? "Sign out ↗" : "Sign in ↗";
    document.querySelector("#welcome").textContent = signedIn ? "Your services, your spaces. Everything is here." : "Public services, all in one place. Sign in for the rest.";
    const unavailable = services.filter(service => service.status === "down").length;
    const uncertain = services.filter(service => service.status !== "up" && service.status !== "down").length;
    notice.className = unavailable || authenticationFailed ? "notice-bad" : "";
    notice.textContent = authenticationFailed ? "Sign-in status is unavailable. Showing public services." : unavailable ? `${unavailable} service${unavailable === 1 ? " needs" : "s need"} attention${uncertain ? ` · ${uncertain} other checks need review` : ""}.` : uncertain ? `${uncertain} service${uncertain === 1 ? " has" : "s have"} an unknown, paused, or pending check.` : "Everything looks good.";
    render();
  } catch {
    // Clear protected data on any failed refresh rather than retaining a stale session.
    services = services.filter(service => service.public).map(service => ({...service, status: "unknown", checks: service.checks.map(check => ({...check, status: "unknown"}))}));
    signedIn = false;
    generated = null;
    document.querySelector("#user").textContent = "";
    document.querySelector("#auth").href = "/login";
    document.querySelector("#auth").textContent = "Sign in ↗";
    notice.className = "notice-bad";
    notice.textContent = "Could not refresh status. Retrying shortly.";
    render();
  } finally { refreshing = false; }
}

for (const [id, value] of [["all", false], ["issues", true]]) {
  document.querySelector(`#${id}`).addEventListener("click", () => {
    issuesOnly = value;
    for (const button of document.querySelectorAll(".filters button")) {
      const selected = button.id === id;
      button.classList.toggle("selected", selected);
      button.setAttribute("aria-pressed", String(selected));
    }
    render();
  });
}
search.addEventListener("input", render);
document.addEventListener("keydown", event => {
  if (event.key === "/" && !["INPUT", "TEXTAREA"].includes(document.activeElement.tagName)) {
    event.preventDefault();
    search.focus();
  }
});
document.addEventListener("visibilitychange", () => { if (!document.hidden) refresh(); });
refresh();
setInterval(() => { if (!document.hidden) refresh(); }, 30000);
