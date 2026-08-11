import fs from "node:fs";
import { promises as fsPromises } from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { config, requireEnv } from "./config.js";

function storageRoot() {
  return path.resolve(
    requireEnv("POSTPLAN_STORAGE_DIR", config.storageDir)
  );
}

function objectPath(key) {
  if (typeof key !== "string" || !key) {
    throw new Error("Invalid object key.");
  }

  const segments = key.split("/");
  if (
    segments.some(
      (segment) =>
        !segment || segment === "." || segment === ".." || segment.includes("\0")
    )
  ) {
    throw new Error("Invalid object key.");
  }

  const root = storageRoot();
  const target = path.resolve(root, ...segments);
  if (!target.startsWith(`${root}${path.sep}`)) {
    throw new Error("Object key escapes the storage directory.");
  }
  return target;
}

export function assertStorageConfigured() {
  const root = storageRoot();
  fs.mkdirSync(root, { recursive: true, mode: 0o700 });
  fs.accessSync(root, fs.constants.R_OK | fs.constants.W_OK);
}

export async function putHtmlObject(key, html) {
  const target = objectPath(key);
  const directory = path.dirname(target);
  const temporary = `${target}.${randomUUID()}.tmp`;

  await fsPromises.mkdir(directory, { recursive: true, mode: 0o700 });
  try {
    await fsPromises.writeFile(temporary, html, {
      encoding: "utf8",
      flag: "wx",
      mode: 0o600
    });
    await fsPromises.rename(temporary, target);
  } catch (error) {
    await fsPromises.rm(temporary, { force: true }).catch(() => {});
    throw error;
  }
}

export async function getHtmlObject(key) {
  return fsPromises.readFile(objectPath(key), "utf8");
}
