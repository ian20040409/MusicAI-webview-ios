export default {
  async fetch(_req, env) {
    const version = parseInt(cleanOrDefault(env.VERSION, "3"), 10);
    const home = cleanOrDefault(env.HOME_URL, "https://linyounttu.dpdns.org/");
    const userAgent = cleanOrDefault(env.USER_AGENT, "MusicAI/1.0 (lnu)");
    const externalAppURL = cleanOrDefault(env.EXTERNAL_APP_URL, "unitymusicapp1007://");
    const showShareOptions = parseBoolean(cleanOrDefault(env.SHOW_SHARE_OPTIONS, "true"));

    // 確保 home 一定是 https
    let homeURL = home;
    try {
      const u = new URL(homeURL);
      if (u.protocol !== "https:") throw new Error("only https");
    } catch {
      homeURL = "https://linyounttu.dpdns.org/";
    }

    const payload = {
      version,
      home_url: homeURL,
      user_agent: userAgent,
      show_share_options: typeof showShareOptions === "boolean" ? showShareOptions : true,
      external_app_url: externalAppURL
    };

    return new Response(JSON.stringify(payload), {
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store, no-cache, must-revalidate",
        "etag": `"v${version}"`,
      }
    });
  }
};

// ✅ 若是空白或輸入 "default"（不分大小寫），會使用預設值
function cleanOrDefault(value, defaultValue) {
  if (value === null || value === undefined) return defaultValue;

  const str = String(value).trim();
  if (!str.length) return defaultValue;

  // 如果輸入 Default / default / DEFAULT 都視為用預設值
  if (str.toLowerCase() === "default") return defaultValue;

  return str;
}

function parseBoolean(value) {
  if (typeof value === "boolean") return value;
  if (value === null || value === undefined) return undefined;
  const normalized = String(value).trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "off"].includes(normalized)) return false;
  if (normalized === "default") return undefined; // default 時交由上層預設處理
  return undefined;
}