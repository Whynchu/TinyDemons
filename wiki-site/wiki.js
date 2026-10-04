const PAGES = [
  { id: "README", title: "Wiki home", file: "README.md" },
  { id: "game-at-a-glance", title: "Game at a glance", file: "game-at-a-glance.md" },
  { id: "systems-map", title: "Systems map", file: "systems-map.md" },
  { id: "visuals-and-experiments", title: "Visuals & experiments", file: "visuals-and-experiments.md" },
  { id: "feature-brief-template", title: "Feature brief template", file: "feature-brief-template.md" },
  { id: "maintenance", title: "Wiki maintenance", file: "maintenance.md" },
];

const article = document.querySelector("#article");
const search = document.querySelector("#search");
const sidebar = document.querySelector("#sidebar");
const menuButton = document.querySelector("#menu-button");

function escapeHTML(value) {
  return value.replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]);
}

function githubURL(target, pageFile) {
  if (/^(https?:|mailto:|#)/i.test(target)) return target;
  const base = `https://github.com/Whynchu/TinyDemons/${target.endsWith("/") ? "tree" : "blob"}/main/docs/wiki/${pageFile}`;
  try {
    const source = new URL(base);
    const resolved = new URL(target, source);
    const path = resolved.pathname.replace("/Whynchu/TinyDemons/blob/main/", "").replace("/Whynchu/TinyDemons/tree/main/", "");
    const kind = target.endsWith("/") ? "tree" : "blob";
    return `https://github.com/Whynchu/TinyDemons/${kind}/main/${path}${resolved.hash}`;
  } catch {
    return target;
  }
}

function inlineMarkdown(text, pageFile) {
  let html = escapeHTML(text);
  html = html.replace(/`([^`]+)`/g, "<code>$1</code>");
  html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/\*([^*]+)\*/g, "<em>$1</em>");
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_all, label, target) => {
    const href = escapeHTML(githubURL(target, pageFile));
    return `<a href="${href}" target="_blank" rel="noreferrer">${label}</a>`;
  });
  return html;
}

function renderMarkdown(markdown, pageFile) {
  const lines = markdown.replaceAll("\r", "").split("\n");
  const out = [];
  let paragraph = [];
  let listType = "";
  let inCode = false;
  let code = [];
  const flushParagraph = () => {
    if (paragraph.length) out.push(`<p>${inlineMarkdown(paragraph.join(" "), pageFile)}</p>`);
    paragraph = [];
  };
  const closeList = () => {
    if (listType) out.push(`</${listType}>`);
    listType = "";
  };
  const closeTable = (rows) => {
    if (!rows.length) return;
    const cells = (line) => line.trim().replace(/^\||\|$/g, "").split("|").map((cell) => cell.trim());
    const header = cells(rows[0]);
    const body = rows.slice(2).map(cells);
    out.push(`<table><thead><tr>${header.map((cell) => `<th>${inlineMarkdown(cell, pageFile)}</th>`).join("")}</tr></thead><tbody>`);
    for (const row of body) out.push(`<tr>${header.map((_cell, index) => `<td>${inlineMarkdown(row[index] || "", pageFile)}</td>`).join("")}</tr>`);
    out.push("</tbody></table>");
  };

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (inCode) {
      if (/^\s*```/.test(line)) {
        out.push(`<pre><code>${escapeHTML(code.join("\n"))}</code></pre>`);
        code = [];
        inCode = false;
      } else code.push(line);
      continue;
    }
    if (/^\s*```/.test(line)) {
      flushParagraph(); closeList(); inCode = true; continue;
    }
    if (line.trim() === "") { flushParagraph(); closeList(); continue; }
    if (/^\|.*\|$/.test(line.trim())) {
      flushParagraph(); closeList();
      const rows = [line.trim()];
      while (index + 1 < lines.length && /^\s*\|.*\|\s*$/.test(lines[index + 1])) rows.push(lines[++index].trim());
      closeTable(rows);
      continue;
    }
    const heading = line.match(/^(#{1,3})\s+(.*)$/);
    if (heading) {
      flushParagraph(); closeList();
      const level = heading[1].length;
      const text = heading[2].replace(/\s+#+\s*$/, "");
      out.push(`<h${level}>${inlineMarkdown(text, pageFile)}</h${level}>`);
      continue;
    }
    if (/^\s*(---+|\*\*\*+)\s*$/.test(line)) { flushParagraph(); closeList(); out.push("<hr>"); continue; }
    const quote = line.match(/^>\s?(.*)$/);
    if (quote) { flushParagraph(); closeList(); out.push(`<blockquote><p>${inlineMarkdown(quote[1], pageFile)}</p></blockquote>`); continue; }
    const item = line.match(/^\s*(?:[-*]\s+|(\d+)\.\s+)(.*)$/);
    if (item) {
      flushParagraph();
      const nextType = item[1] ? "ol" : "ul";
      if (listType !== nextType) { closeList(); out.push(`<${nextType}>`); listType = nextType; }
      out.push(`<li>${inlineMarkdown(item[2], pageFile)}</li>`);
      continue;
    }
    closeList(); paragraph.push(line.trim());
  }
  flushParagraph(); closeList();
  if (inCode) out.push(`<pre><code>${escapeHTML(code.join("\n"))}</code></pre>`);
  return out.join("\n");
}

async function openPage(id) {
  const page = PAGES.find((candidate) => candidate.id === id) || PAGES[0];
  document.querySelectorAll(".nav-link").forEach((link) => link.classList.toggle("active", link.dataset.page === page.id));
  document.querySelector("#crumb").textContent = page.title;
  document.title = `${page.title} · Tiny Demons Wiki`;
  history.replaceState(null, "", page.id === "README" ? location.pathname : `?page=${page.id}`);
  article.innerHTML = '<div class="loading"><span></span>Loading design notes…</div>';
  try {
    const response = await fetch(`content/${page.file}`);
    if (!response.ok) throw new Error(`Could not load ${page.file}`);
    const markdown = await response.text();
    article.innerHTML = renderMarkdown(markdown, page.file);
    article.querySelector("h1")?.insertAdjacentHTML("afterend", '<span class="status">Design reference</span>');
    sidebar.classList.remove("open");
    menuButton?.setAttribute("aria-expanded", "false");
  } catch (error) {
    article.innerHTML = `<p class="error">${escapeHTML(error.message)}. Build the wiki with <code>tools/build_design_wiki.ps1</code>, then serve the output over HTTP.</p>`;
  }
}

document.querySelectorAll(".nav-link").forEach((link) => link.addEventListener("click", (event) => {
  event.preventDefault();
  openPage(link.dataset.page);
}));

search.addEventListener("input", () => {
  const query = search.value.trim().toLowerCase();
  document.querySelectorAll(".nav-link").forEach((link) => {
    link.hidden = query.length > 0 && !link.textContent.toLowerCase().includes(query);
  });
});

menuButton?.addEventListener("click", () => {
  const open = sidebar.classList.toggle("open");
  menuButton.setAttribute("aria-expanded", String(open));
});

openPage(new URLSearchParams(location.search).get("page") || "README");
