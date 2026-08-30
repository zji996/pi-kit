import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const sources = readFileSync(resolve(root, "packages.lock"), "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#"));

if (sources.length === 0) {
  throw new Error("packages.lock is empty");
}

for (const filename of ["install.sh", "install.ps1"]) {
  const contents = readFileSync(resolve(root, filename), "utf8");
  for (const source of sources) {
    if (!contents.includes(source)) {
      throw new Error(`${filename} is missing ${source}`);
    }
  }
}

console.log(`pi-kit: checked ${sources.length} pinned packages`);
