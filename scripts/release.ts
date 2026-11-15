import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { cp, mkdir, mkdtemp, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { buildProject } from "./build";
import { dist, root, run } from "./tools";

export const runtimeFiles = ["Overlay.qml", "bindings.lua", "controllers", "adapters", "components", "previews", "generated", "i18n"];

async function files(directory: string, prefix = ""): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const result: string[] = [];
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name, "en"))) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isSymbolicLink()) throw new Error(`Release contains a symlink: ${relative}`);
    if (entry.isDirectory()) result.push(...await files(join(directory, entry.name), relative));
    else result.push(relative);
  }
  return result;
}

async function checkGitInclusion(stage: string): Promise<void> {
  const paths = ["manifest.json", ...await files(join(stage, "runtime"), "runtime")];
  const result = spawnSync("git", ["check-ignore", "--no-index", "--", ...paths], { cwd: root, encoding: "utf8" });
  if (result.error) throw result.error;
  if (result.status === 0) throw new Error(`Required release files are ignored by Git:\n${result.stdout}`);
  if (result.status !== 1) throw new Error(`Cannot check Git release inclusion: ${result.stderr}`);
}

export async function releaseImage(): Promise<{ stage: string; buildId: string }> {
  const stage = await mkdtemp(join(root, ".stage-release-"));
  try {
    const content = join(stage, "content");
    await mkdir(content);
    for (const file of runtimeFiles) await cp(join(dist, file), join(content, file), { recursive: true });
    const manifest = JSON.parse(await readFile(join(dist, "manifest.json"), "utf8")) as Record<string, unknown>;
    const hash = createHash("sha256").update(JSON.stringify(manifest));
    for (const file of await files(content)) hash.update(file).update("\0").update(await readFile(join(content, file))).update("\0");
    const buildId = hash.digest("hex").slice(0, 24);
    await mkdir(join(stage, "runtime"));
    await rename(content, join(stage, "runtime", buildId));
    manifest["buildId"] = buildId;
    manifest["entryPoints"] = { overlay: `runtime/${buildId}/Overlay.qml` };
    await writeFile(join(stage, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
    return { stage, buildId };
  } catch (error) {
    await rm(stage, { recursive: true, force: true });
    throw error;
  }
}

export async function prepareRelease(validate = true): Promise<string> {
  const { stage, buildId } = await releaseImage();
  try {
    if (validate) run("omarchy", ["plugin", "validate", stage]);
    await checkGitInclusion(stage);
    // Publish the new entry's files before switching the manifest. Remove old
    // runtime directories only after the new entry is complete.
    await mkdir(join(root, "runtime"), { recursive: true });
    await rm(join(root, "runtime", buildId), { recursive: true, force: true });
    await rename(join(stage, "runtime", buildId), join(root, "runtime", buildId));
    await rename(join(stage, "manifest.json"), join(root, "manifest.json"));
    for (const entry of await readdir(join(root, "runtime"))) {
      if (entry !== buildId) await rm(join(root, "runtime", entry), { recursive: true, force: true });
    }
    console.log(`Prepared Git release runtime/${buildId}; commit runtime/ and manifest.json together.`);
    return buildId;
  } finally {
    await rm(stage, { recursive: true, force: true });
  }
}

export async function checkRelease(): Promise<void> {
  const { stage } = await releaseImage();
  try {
    await checkGitInclusion(stage);
    for (const relative of ["manifest.json", ...await files(join(stage, "runtime"), "runtime")]) {
      const expected = await readFile(join(stage, relative));
      let actual: Buffer;
      try { actual = await readFile(join(root, relative)); }
      catch { throw new Error(`Missing Git release file: ${relative}; run npm run release`); }
      if (!expected.equals(actual)) throw new Error(`Stale Git release file: ${relative}; run npm run release`);
    }
    const expectedFiles = await files(join(stage, "runtime"));
    const actualFiles = await files(join(root, "runtime"));
    if (JSON.stringify(expectedFiles) !== JSON.stringify(actualFiles)) throw new Error("Unexpected runtime files; run npm run release");
    console.log("Git release matches the source build.");
  } finally {
    await rm(stage, { recursive: true, force: true });
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (!process.argv.includes("--built")) await buildProject();
    if (process.argv.includes("--check")) await checkRelease();
    else await prepareRelease();
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  }
}
