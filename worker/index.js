/**
 * Cloudflare Worker — GitHub Issues proxy for CalendarAlarm contact form
 *
 * Secrets (set via `wrangler secret put`):
 *   GITHUB_TOKEN  : Fine-grained PAT with Issues: Write on RyoyaYahagi/calendar-alerm
 *
 * Allowed origins: configure ALLOWED_ORIGIN in wrangler.toml or hardcode below.
 */

const GITHUB_REPO = "RyoyaYahagi/calendar-alerm";
const GITHUB_API  = `https://api.github.com/repos/${GITHUB_REPO}/issues`;

const CATEGORY_LABELS = {
  bug:     ["bug"],
  feature: ["enhancement"],
  question:["question"],
  other:   [],
};

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return corsResponse(new Response(null, { status: 204 }));
    }

    if (request.method !== "POST") {
      return corsResponse(new Response("Method Not Allowed", { status: 405 }));
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return corsResponse(new Response("Invalid JSON", { status: 400 }));
    }

    const { category, subject, email, message } = payload;

    if (!subject?.trim() || !message?.trim()) {
      return corsResponse(new Response("subject and message are required", { status: 422 }));
    }

    const categoryKey = category in CATEGORY_LABELS ? category : "other";
    const labels = CATEGORY_LABELS[categoryKey];

    const emailLine = email?.trim() ? `**連絡先**: ${email.trim()}\n` : "";
    const issueBody = `${emailLine}**カテゴリ**: ${categoryKey}\n\n---\n\n${message.trim()}`;

    const ghResponse = await fetch(GITHUB_API, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        "Content-Type": "application/json",
        Accept: "application/vnd.github+json",
        "User-Agent": "CalendarAlarm-ContactProxy/1.0",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      body: JSON.stringify({ title: subject.trim(), body: issueBody, labels }),
    });

    if (!ghResponse.ok) {
      const text = await ghResponse.text();
      console.error("GitHub API error", ghResponse.status, text);
      return corsResponse(new Response("Failed to create issue", { status: 502 }));
    }

    const issue = await ghResponse.json();
    return corsResponse(Response.json({ number: issue.number, url: issue.html_url }));
  },
};

function corsResponse(response) {
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Content-Type");
  return new Response(response.body, { status: response.status, headers });
}
