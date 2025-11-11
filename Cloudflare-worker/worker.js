export default {
  async fetch(_req, env) {
    let version = parseInt(env.VERSION || "-99", 10) || 3;
    let home = env.HOME_URL || "https://linyounttu.dpdns.org/";

    try {
      const u = new URL(home);
      if (u.protocol !== "https:") throw new Error("only https");
    } catch {
      home = "https://linyounttu.dpdns.org/";
    }

    const body = JSON.stringify({ version, home_url: home });

    return new Response(body, {
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store, no-cache, must-revalidate",
        "etag": `"v${version}"`,
      }
    });
  }
};