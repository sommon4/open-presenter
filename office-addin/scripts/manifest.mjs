// Renders manifest.xml from manifest.template.xml.
//
//   npm run manifest                      -> https://localhost:3000 (dev server)
//   npm run manifest -- https://poll.example.com
//
// In production Phoenix serves the manifest itself at /office/manifest.xml
// with the configured BASE_URL, so this script is only needed for sideloading
// against the Vite dev server.
import { readFileSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";

const baseUrl = (process.argv[2] || "https://localhost:3000").replace(/\/+$/, "");
const id = process.env.OFFICE_ADDIN_ID || "5f2b4d0e-8c1a-4c6e-9a3b-0a4d6e7f8b91";
const version = process.env.npm_package_version ? `${process.env.npm_package_version}.0` : "0.1.0.0";

const xml = readFileSync(new URL("../manifest.template.xml", import.meta.url), "utf8")
  .replaceAll("{{BASE_URL}}", baseUrl)
  .replaceAll("{{ADDIN_ID}}", id === "random" ? randomUUID() : id)
  .replaceAll("{{VERSION}}", version);

writeFileSync(new URL("../manifest.xml", import.meta.url), xml);
console.log(`manifest.xml written for ${baseUrl}`);
