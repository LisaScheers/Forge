import { createHash } from "node:crypto";

const authentikClientSecret = process.env.AUTHENTIK_CLIENT_SECRET;

function deriveSessionSecret(clientSecret) {
  if (!clientSecret) return undefined;

  return createHash("sha256")
    .update("postplan-session-v1\0")
    .update(clientSecret)
    .digest("base64url");
}

export const config = {
  port: Number(process.env.PORT || 3000),
  databaseUrl: process.env.DATABASE_URL,
  bootstrapApiKey: process.env.POSTPLAN_BOOTSTRAP_API_KEY,
  publicBaseUrl: process.env.POSTPLAN_PUBLIC_BASE_URL,
  maxHtmlBytes: Number(process.env.MAX_HTML_BYTES || 512 * 1024),
  sessionSecret:
    process.env.POSTPLAN_SESSION_SECRET ||
    deriveSessionSecret(authentikClientSecret),
  storageDir: process.env.POSTPLAN_STORAGE_DIR,
  authentik: {
    baseUrl: (process.env.AUTHENTIK_BASE_URL || "").replace(/\/+$/, ""),
    issuerUrl: process.env.AUTHENTIK_ISSUER_URL,
    clientId: process.env.AUTHENTIK_CLIENT_ID,
    clientSecret: authentikClientSecret
  }
};

export function requireEnv(name, value) {
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}
