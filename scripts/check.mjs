import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const sources = read("packages.list")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#"));

if (sources.length === 0) throw new Error("packages.list is empty");
for (const source of sources) {
  const withoutPrefix = source.replace(/^npm:/, "");
  if (!source.startsWith("npm:") || withoutPrefix.lastIndexOf("@") > 0) {
    throw new Error(`packages.list source must be unversioned npm: ${source}`);
  }
}

const unixSettingsText = read("settings.unix.json");
const windowsSettingsText = read("settings.windows.json");
const unixSettings = JSON.parse(unixSettingsText);
const windowsSettings = JSON.parse(windowsSettingsText);
for (const [platform, settings] of [["unix", unixSettings], ["windows", windowsSettings]]) {
  if (JSON.stringify(settings.packages) !== JSON.stringify(sources)) {
    throw new Error(`${platform} settings packages differ from packages.list`);
  }
  if (settings.defaultThinkingLevel !== "high") throw new Error(`${platform} default thinking must be high`);
  if (settings.compaction?.reserveTokens !== 32768 || settings.compaction?.keepRecentTokens !== 40000) {
    throw new Error(`${platform} compaction budget is not canonical`);
  }
  if (settings.branchSummary?.reserveTokens !== 32768) throw new Error(`${platform} branch reserve is not canonical`);
  for (const excluded of ["grep", "find", "ls"]) {
    if (settings.defaultTools.includes(excluded)) throw new Error(`${platform} settings enable ${excluded}`);
  }
}

const shellInstaller = read("install.sh");
const powershellInstaller = read("install.ps1");
for (const source of sources) {
  if (!shellInstaller.includes(source)) throw new Error(`install.sh is missing ${source}`);
  if (!powershellInstaller.includes(source)) throw new Error(`install.ps1 is missing ${source}`);
}
if (!shellInstaller.includes(unixSettingsText)) throw new Error("install.sh embedded settings differ from settings.unix.json");
for (const value of ['"powershell"', 'reserveTokens = 32768', 'keepRecentTokens = 40000']) {
  if (!powershellInstaller.includes(value)) throw new Error(`install.ps1 is missing canonical value ${value}`);
}

const skill = read("skills/playwright-cli/SKILL.md");
if (!shellInstaller.includes(skill)) throw new Error("install.sh embedded Playwright skill differs from the managed skill");
if (!powershellInstaller.includes(skill.trimEnd())) {
  throw new Error("install.ps1 embedded Playwright skill differs from the managed skill");
}

console.log(`pi-kit: checked declarative settings, skill, and ${sources.length} latest-tracking packages`);
