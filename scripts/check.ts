import { access, cp, mkdir, readFile, readdir, symlink, writeFile } from "node:fs/promises";
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
  // This Quickshell build omits the private PostReloadHook base from the
  // GlobalShortcut tooling module. Copy the installed metadata and include the
  // actual base declaration locally; runtime files and checks stay unchanged.
  const installed = "/usr/lib/qt6/qml/Quickshell";
  await cp(installed, join(importRoot, "Quickshell"), { recursive: true });
  const coreTypes = await readFile(join(installed, "quickshell-core.qmltypes"), "utf8");
  const nameAt = coreTypes.indexOf('name: "PostReloadHook"');
  if (nameAt >= 0) {
    const start = coreTypes.lastIndexOf("    Component {", nameAt);
    const end = coreTypes.indexOf("\n    }", nameAt) + 6;
    const path = join(importRoot, "Quickshell", "Hyprland", "_GlobalShortcuts", "quickshell-hyprland-global-shortcuts.qmltypes");
    const types = await readFile(path, "utf8");
    if (!types.includes('name: "PostReloadHook"')) {
      const closing = types.lastIndexOf("\n}");
      await writeFile(path, types.slice(0, closing) + "\n" + coreTypes.slice(start, end) + types.slice(closing));
    }
  }
  run(qtTool("qmllint"), ["--bare", "-I", importRoot, "-I", "/usr/lib/qt6/qml", "-W", "0", ...await qmlFiles(dist)]);
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
    if (mode === "all") {
      run("luac", ["-p", "bindings.lua"]);
      run("bash", ["-n", "scripts/install.sh", "scripts/uninstall.sh"]);
      run("python3", ["-m", "unittest", "discover", "-s", "tests/installer"]);
    }
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}
