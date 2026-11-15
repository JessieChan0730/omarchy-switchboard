import { watch, type FSWatcher } from "node:fs";
import { cp, mkdir, mkdtemp, readFile, rename, rm, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";
import { checkTypeScript, dist, root } from "./tools";

const runtimeFiles = [
  "Overlay.qml", "bindings.lua", "README.md", "README.en.md", "LICENSE",
  "controllers", "adapters", "previews", "components", "i18n", "docs",
];

export async function buildProject(): Promise<void> {
  checkTypeScript();
  const stage = await mkdtemp(join(root, ".stage-"));
  try {
    // Build into staging so failed builds leave the last complete plugin intact.
    await Promise.all(runtimeFiles.map((file) => cp(join(root, file), join(stage, file), {
      recursive: true,
      filter: (path) => !path.split(/[\\/]/).includes("__pycache__"),
    })));
    await cp(join(root, "manifest.source.json"), join(stage, "manifest.json"));
    await build({
      absWorkingDir: root,
      entryPoints: ["src/logic/index.ts"],
      outfile: join(stage, "generated", "Logic.mjs"),
      bundle: true,
      splitting: false,
      platform: "neutral",
      format: "esm",
      target: "es2016",
      sourcemap: false,
      logLevel: "warning",
    });

    await mkdir(join(root, "dist"), { recursive: true });
    const previous = join(root, "dist", ".previous-plugin");
    await rm(previous, { recursive: true, force: true });
    let hadPrevious = false;
    try {
      await rename(dist, previous);
      hadPrevious = true;
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error;
    }
    try {
      await rename(stage, dist);
    } catch (error) {
      if (hadPrevious) await rename(previous, dist);
      throw error;
    }
    await rm(previous, { recursive: true, force: true });

    // Keep source-relative QML imports usable for editor tooling after a build.
    await mkdir(join(root, "generated"), { recursive: true });
    const contents = await readFile(join(dist, "generated", "Logic.mjs"));
    const temporary = join(root, "generated", ".Logic.mjs.tmp");
    await writeFile(temporary, contents);
    await rename(temporary, join(root, "generated", "Logic.mjs"));
    console.log("Built dist/plugin (QML + TypeScript ESM + Lua + translations)");
  } finally {
    await rm(stage, { recursive: true, force: true });
  }
}

async function watchProject(): Promise<void> {
  await buildProject();
  let timer: ReturnType<typeof setTimeout> | undefined;
  let rebuilding = false;
  let pending = false;

  async function rebuild(): Promise<void> {
    if (rebuilding) {
      pending = true;
      return;
    }
    rebuilding = true;
    try {
      await buildProject();
    } catch (error) {
      console.error(error instanceof Error ? error.message : error);
    } finally {
      rebuilding = false;
      if (pending) {
        pending = false;
        schedule();
      }
    }
  }

  function schedule(): void {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => { void rebuild(); }, 150);
  }

  const watchers: FSWatcher[] = [...runtimeFiles, "manifest.source.json", "src", "scripts", "tsconfig.json", "tsconfig.tools.json"]
    .map((file) => watch(join(root, file), { recursive: true }, schedule));
  for (const watcher of watchers) watcher.on("error", (error) => {
    console.error(error.message);
    process.exitCode = 1;
    for (const active of watchers) active.close();
  });

  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.once(signal, () => {
      if (timer) clearTimeout(timer);
      for (const watcher of watchers) watcher.close();
    });
  }
  console.log("Watching source files; output stays inside the repository.");
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (process.argv.includes("--watch")) await watchProject();
    else await buildProject();
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  }
}
