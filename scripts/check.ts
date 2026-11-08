import { access, mkdir, readdir, symlink } from "node:fs/promises";
import { join } from "node:path";
import { buildProject } from "./build";
import { checkTypeScript, dist, qtTool, root, run } from "./tools";

async function qmlFiles(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const groups = await Promise.all(entries.map(async (entry): Promise<string[]> => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return qmlFiles(path);
    return entry.name.endsWith(".qml") ? [path] : [];
  }));
  return groups.flat();
}

async function lintQml(): Promise<void> {
  const shellRoot = process.env["OMARCHY_SHELL_DIR"] ?? "/usr/share/omarchy/shell";
  await access(join(shellRoot, "Commons", "qmldir"));
  const importRoot = join(root, ".cache", "qml-imports");
  await mkdir(importRoot, { recursive: true });
  const shellImport = join(importRoot, "qs");
  try {
    await symlink(shellRoot, shellImport, "dir");
  } catch (error) {
    if (!(error instanceof Error && "code" in error && error.code === "EEXIST")) throw error;
  }
  run(qtTool("qmllint"), ["-I", importRoot, "-I", "/usr/lib/qt6/qml", "-W", "0", ...await qmlFiles(dist)]);
}

function testQt(): void {
  run(qtTool("qmltestrunner"), ["-input", "tests/unit"], {
    ...process.env,
    QT_QPA_PLATFORM: "offscreen",
    QSG_RHI_BACKEND: "software",
  });
}

try {
  const mode = process.argv[2] ?? "all";
  if (!["types", "lint", "qt", "manifest", "all"].includes(mode)) {
    throw new Error(`Unknown check: ${mode}`);
  }
  if (mode === "types") checkTypeScript();
  else {
    await buildProject();
    if (mode === "all" || mode === "lint") await lintQml();
    if (mode === "all" || mode === "qt") testQt();
    if (mode === "all" || mode === "manifest") run("omarchy", ["plugin", "validate", dist]);
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}
