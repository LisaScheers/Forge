{pkgs}: let
  badGatewayPage = pkgs.writeTextDir "502.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Service unavailable</title>
        <style>
          :root {
            color-scheme: light dark;
            --bg: #f6f3ee;
            --panel: #ffffff;
            --text: #1c2321;
            --muted: #64706c;
            --accent: #d95f45;
            --accent-soft: #f3d8cf;
            --line: #ded8cf;
          }

          @media (prefers-color-scheme: dark) {
            :root {
              --bg: #111816;
              --panel: #18211f;
              --text: #eef3ee;
              --muted: #aab7b1;
              --accent: #ff8a65;
              --accent-soft: #42241d;
              --line: #2b3935;
            }
          }

          * {
            box-sizing: border-box;
          }

          body {
            min-height: 100vh;
            margin: 0;
            display: grid;
            place-items: center;
            padding: 32px;
            background:
              radial-gradient(circle at 20% 15%, rgba(217, 95, 69, 0.16), transparent 28%),
              linear-gradient(145deg, var(--bg), color-mix(in srgb, var(--bg) 78%, #9fb8aa));
            color: var(--text);
            font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          }

          main {
            width: min(100%, 680px);
            border: 1px solid var(--line);
            border-radius: 8px;
            background: color-mix(in srgb, var(--panel) 92%, transparent);
            box-shadow: 0 24px 70px rgba(0, 0, 0, 0.14);
            padding: clamp(28px, 7vw, 56px);
          }

          .code {
            width: max-content;
            margin-bottom: 28px;
            border-radius: 999px;
            background: var(--accent-soft);
            color: var(--accent);
            padding: 8px 14px;
            font-size: 0.78rem;
            font-weight: 800;
            letter-spacing: 0.08em;
            text-transform: uppercase;
          }

          h1 {
            margin: 0;
            font-size: clamp(2rem, 7vw, 4.5rem);
            line-height: 0.95;
            letter-spacing: 0;
          }

          p {
            max-width: 54ch;
            margin: 24px 0 0;
            color: var(--muted);
            font-size: clamp(1rem, 2.6vw, 1.2rem);
            line-height: 1.65;
          }

          .status {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            margin-top: 34px;
            color: var(--muted);
            font-size: 0.95rem;
          }

          .status span {
            border: 1px solid var(--line);
            border-radius: 999px;
            padding: 8px 12px;
            background: color-mix(in srgb, var(--panel) 80%, transparent);
          }
        </style>
      </head>
      <body>
        <main>
          <div class="code">502 bad gateway</div>
          <h1>This service is taking a short break.</h1>
          <p>
            The site is reachable, but the application behind it did not respond correctly.
            Please try again in a moment.
          </p>
          <div class="status" aria-label="Request status">
            <span>Gateway online</span>
            <span>Upstream unavailable</span>
          </div>
        </main>
      </body>
    </html>
  '';
in {
  extraConfig = ''
    proxy_intercept_errors on;
    error_page 502 =502 /502.html;
  '';

  locations."= /502.html" = {
    root = "${badGatewayPage}";
    extraConfig = ''
      internal;
      default_type text/html;
      add_header Cache-Control "no-store" always;
    '';
  };
}
