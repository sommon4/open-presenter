import { defineConfig } from "vite";
import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// Office requires HTTPS even in development. `npm run certs` installs the
// office-addin-dev-certs CA and writes localhost.key/crt into ~/.office-addin-dev-certs.
function devCerts() {
  const dir = join(homedir(), ".office-addin-dev-certs");
  const key = join(dir, "localhost.key");
  const cert = join(dir, "localhost.crt");
  if (existsSync(key) && existsSync(cert)) {
    return { key: readFileSync(key), cert: readFileSync(cert) };
  }
  return undefined;
}

export default defineConfig(({ command }) => ({
  // In production the add-in is served by Phoenix at https://<host>/office/
  base: command === "build" ? "/office/" : "/",
  build: {
    outDir: "dist",
    emptyOutDir: true,
    target: "es2019",
    sourcemap: false,
  },
  server: {
    port: 3000,
    https: devCerts(),
    headers: { "Access-Control-Allow-Origin": "*" },
  },
}));
