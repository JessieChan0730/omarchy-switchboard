import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

export const root = fileURLToPath(new URL("../", import.meta.url));
export const dist = join(root, "dist", "plugin");

export function run(command: string, args: readonly string[], env = process.env): void {
  const result = spawnSync(command, [...args], { cwd: root, stdio: "inherit", env });
  if (result.error) throw new Error(`Cannot run ${command}: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`${command} failed (${result.status ?? result.signal})`);
}

export function checkTypeScript(): void {
  const compiler = join(root, "node_modules", "typescript", "bin", "tsc");
  for (const config of ["tsconfig.json", "tsconfig.tools.json"]) {
    run(process.execPath, [compiler, "--noEmit", "--project", config]);
  }
}

export function qtTool(name: string): string {
  for (const directory of [process.env["QT_BIN_DIR"], "/usr/lib/qt6/bin"]) {
    if (directory && existsSync(join(directory, name))) return join(directory, name);
  }
  return name;
}
