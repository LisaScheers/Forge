import { createHash } from "node:crypto";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { config, requireEnv } from "./config.js";
import { randomToken } from "./crypto.js";

let discoveryCache = null;
let jwksCache = null;

export function buildPkce() {
  const verifier = randomToken(32);
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  return { verifier, challenge, state: randomToken(24) };
}

export function buildAuthorizeUrl({ redirectUri, state, challenge }) {
  const baseUrl = requireEnv("AUTHENTIK_BASE_URL", config.authentik.baseUrl);
  const clientId = requireEnv("AUTHENTIK_CLIENT_ID", config.authentik.clientId);
  const url = new URL(`${baseUrl}/application/o/authorize/`);

  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("scope", "openid email profile");
  url.searchParams.set("state", state);
  url.searchParams.set("code_challenge", challenge);
  url.searchParams.set("code_challenge_method", "S256");
  return url.toString();
}

export async function exchangeCode({ code, verifier, redirectUri }) {
  const metadata = await getDiscovery();
  const clientId = requireEnv("AUTHENTIK_CLIENT_ID", config.authentik.clientId);
  const clientSecret = requireEnv(
    "AUTHENTIK_CLIENT_SECRET",
    config.authentik.clientSecret
  );
  const response = await fetch(metadata.token_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      code,
      code_verifier: verifier
    }),
    signal: AbortSignal.timeout(10_000)
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      `Authentik token exchange failed: ${body.error_description || body.error || response.status}`
    );
  }
  if (typeof body.id_token !== "string") {
    throw new Error("Authentik token exchange returned no id_token.");
  }
  return body;
}

export async function verifyIdToken(idToken) {
  const metadata = await getDiscovery();
  const clientId = requireEnv("AUTHENTIK_CLIENT_ID", config.authentik.clientId);
  const { payload } = await jwtVerify(idToken, await getJwks(), {
    issuer: metadata.issuer,
    audience: clientId
  });

  if (typeof payload.sub !== "string" || !payload.sub) {
    throw new Error("Authentik id_token is missing sub.");
  }

  return {
    ...payload,
    pairwise_sub: payload.sub,
    pii_sub: payload.sub
  };
}

async function getDiscovery() {
  discoveryCache ||= (async () => {
    const issuer = requireEnv(
      "AUTHENTIK_ISSUER_URL",
      config.authentik.issuerUrl
    );
    const discoveryUrl = new URL(
      ".well-known/openid-configuration",
      issuer.endsWith("/") ? issuer : `${issuer}/`
    );
    const response = await fetch(discoveryUrl, {
      signal: AbortSignal.timeout(10_000)
    });
    if (!response.ok) {
      throw new Error(`Authentik discovery failed: ${response.status}`);
    }

    const metadata = await response.json();
    if (
      typeof metadata.issuer !== "string" ||
      typeof metadata.jwks_uri !== "string" ||
      typeof metadata.token_endpoint !== "string"
    ) {
      throw new Error("Authentik discovery document is incomplete.");
    }
    return metadata;
  })().catch((error) => {
    discoveryCache = null;
    throw error;
  });

  return discoveryCache;
}

async function getJwks() {
  if (!jwksCache) {
    const metadata = await getDiscovery();
    jwksCache = createRemoteJWKSet(new URL(metadata.jwks_uri));
  }
  return jwksCache;
}

export function resetAuthentikCaches() {
  discoveryCache = null;
  jwksCache = null;
}
