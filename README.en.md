# Omarchy Switchboard

[简体中文](README.md) | **English**

## Introduction

Omarchy Switchboard is an application, window, and workspace switcher for [Omarchy](https://github.com/omacom/omarchy). It runs inside the existing `omarchy-shell` and provides an application icon list, previews of windows within an application, and a workspace overview to help you move between tasks. Local workspace badges follow Omarchy's `1–9, 0` numbering, with `0` representing the tenth slot. Visiting workspaces outside the monitor's numbering range display `↳ global ID` to avoid duplicate badges. You can scroll when there are more workspaces than fit in the panel.

### Screenshots

**Win+Tab: Workspace overview with live window previews and wallpaper for empty slots.**

![Win+Tab workspace overview](docs/images/workspace-overview.png)

## Keyboard Shortcuts

Installing and enabling the plugin through Omarchy activates the switching shortcuts below by default. `Win` is the Windows key on your keyboard. While a panel is open, you can also use the keyboard and mouse actions in the table.

| Shortcut / Input | Action |
| --- | --- |
| `Win+Tab` | Select the next workspace on the current monitor; release Win to confirm |
| `Win+Shift+Tab` | Select the previous workspace on the current monitor; release Win to confirm |
| `Alt+Tab` | Select the next application on the current workspace; release Alt to confirm |
| `Alt+Shift+Tab` | Select the previous application on the current workspace; release Alt to confirm |
| `Alt+~` | Select the next window within the application; release Alt to confirm |
| `Alt+Shift+~` | Select the previous window within the application; release Alt to confirm |
| `Tab` / `Shift+Tab` | While a panel is open, cycle forward / backward through items |
| Arrow keys | While a panel is open, navigate rows and columns |
| `Enter` / Mouse click | Confirm the selection |
| `Esc` | Cancel and restore the window focus from before the panel opened |
| Mouse wheel | Scroll when the content exceeds the panel size |

Alt+Tab centers each application name below its icon and truncates long names with an ellipsis. Keeping an application with multiple windows highlighted for 700ms automatically opens its window previews, with its most recently used window selected first. Use `Alt+~` / `Alt+Shift+~` to choose another window. Tab moves to another application, collapses the previews, and restarts the delay; releasing Alt activates the selected window.

Window bubbles fade and gently scale in and out, following the system animation setting. Opening window previews directly reveals the application strip and previews together once the first frame is ready, avoiding a brief icon flash. Confirming or cancelling releases input focus immediately.

## Installation

### Install through Omarchy (recommended)

Use a running Omarchy / Hyprland Lua session with matching Quickshell and Qt 6. Runtime dependencies are Git, Python 3, and ImageMagick, included in Omarchy. **Node.js, npm, and compilation on the user's machine are not required.**

```bash
omarchy plugin add https://github.com/JessieChan0730/omarchy-switchboard.git --enable
```

The plugin is installed at `~/.config/omarchy/plugins/jessie.switchboard/`. A new installation enables the switching shortcuts by default; existing shortcut settings take precedence. Disabling or removing the plugin, or turning off its shortcuts, restores your original shortcuts.

### Install from source (development)

Development additionally requires Node.js **22.12 or later**, npm, Lua (`lua`, `luac`), Bash, the Qt tools `qmllint` and `qmltestrunner`, and the Omarchy shell sources.

```bash
git clone https://github.com/JessieChan0730/omarchy-switchboard.git
cd omarchy-switchboard
npm ci
./scripts/install.sh
```

The script runs all checks and deploys a local development build. A first source installation preserves your existing shortcuts. Use `./scripts/install.sh --bindings` to enable the plugin shortcuts or `./scripts/install.sh --no-bindings` to restore your original shortcuts. Repeated deployments retain settings and binding mode.

The installer backs up configuration and any existing plugin with the same ID, removes legacy managed Lua includes, reloads Hyprland and the plugin, and verifies the running instance's build ID and readiness. Failed deployments roll back. The installer refuses to overwrite a Git installation, preserving its checkout and official update support.

### Migrate an existing source installation to Git

Run in the source repository:

```bash
./scripts/migrate.sh
```

The script backs up and uninstalls the managed development installation, installs the Git repository with the official command, and restores settings and binding mode. Failure rolls back the migration. It defaults to the GitHub URL above; use `--url <Git URL>` for another release repository. If the first development installation replaced an earlier plugin with the same ID, resolve that original installation before migrating.

## Check and try the plugin

```bash
# Check plugin and shortcut status
omarchy-shell jessie.switchboard status

# Application list
omarchy-shell shell summon jessie.switchboard '{"mode":"window"}'

# Window previews for the current application
omarchy-shell shell summon jessie.switchboard '{"mode":"app-windows"}'

# Workspace overview for the current monitor
omarchy-shell shell summon jessie.switchboard '{"mode":"workspace"}'
```

`ready` should be `true`; with shortcuts enabled, `bindings` should also be `true`. Use Tab / arrow keys to select, Enter to confirm, and Esc to cancel.

To keep your existing shortcuts and use commands only, run while the plugin is enabled:

```bash
omarchy-shell jessie.switchboard settings '{"bindingsEnabled":false}'

# Enable plugin shortcuts again
omarchy-shell jessie.switchboard settings '{"bindingsEnabled":true}'
```

## Updating

For a Git installation:

```bash
omarchy plugin update jessie.switchboard
```

If you need to reload after updating, run:

```bash
omarchy restart shell
```

Restarting the shell does not download updates. Edits inside a Git installation may prevent fast-forward updates; use the source repository for development.

For a source development installation, run in the checkout:

```bash
git pull --ff-only
npm ci
./scripts/install.sh
```

## Disabling and removing

Both installation types support disabling and enabling:

```bash
omarchy plugin disable jessie.switchboard
omarchy plugin enable jessie.switchboard
```

Remove a Git installation with:

```bash
omarchy plugin remove jessie.switchboard
```

For a development installation, use `./scripts/uninstall.sh` to restore the original plugin entry and any earlier plugin with the same ID. It preserves other plugins, settings, and shortcuts added later. Repeated uninstallation is safe. Backups and installation records remain at `${XDG_STATE_HOME:-~/.local/state}/omarchy-switchboard/`.

## Development

### Workflow

The stack is **QML + TypeScript + Lua**: QML handles the UI and input, TypeScript handles candidates, sorting, and session logic, and Lua handles global shortcuts. TypeScript compiles to `.mjs` modules loaded by Qt; application logic does not depend on Node.js or browser APIs.

After meeting the installation requirements:

```bash
npm ci
npm run dev
```

`npm run dev` watches the source and updates `dist/plugin/` inside the repository. It does not deploy automatically. After making changes, run `./scripts/install.sh` to check and deploy to your current desktop, preserving the existing binding mode.

| Command | Purpose |
| --- | --- |
| `npm run typecheck` | Check application TypeScript and build scripts |
| `npm run build` | Type-check, generate ESM, and assemble `dist/plugin/` |
| `npm run dev` | Watch sources and rebuild |
| `npm run lint:qml` | Check QML and Omarchy / Quickshell imports |
| `npm run test:qt` | Test release ESM and actual component layouts in Qt |
| `npm run validate` | Validate the built Omarchy manifest |
| `npm run release` | Run all checks and prepare the Git runtime and root manifest |
| `npm run check:release` | Rebuild and verify that release files match the sources |
| `npm run check` | Run the full build, QML / Qt / manifest checks, Lua / Bash syntax checks, and installer and wallpaper cache tests |

Set `QT_BIN_DIR` to choose a Qt tools directory or `OMARCHY_SHELL_DIR` to choose an Omarchy shell source directory. QML tooling metadata adjustments are written to the repository's `.cache/`.

### Prepare a Git release

After editing sources and `manifest.source.json`, run:

```bash
npm run release
npm run check:release
```

`manifest.source.json` is the source manifest. The generated root `manifest.json` and `runtime/` must be committed with the sources on the public repository's default branch. The build ID is a content hash of runtime files and the source manifest, so identical inputs produce the same ID. Edit sources and regenerate rather than editing `runtime/` directly. The release script prepares local files; it does not commit, push, or submit a marketplace listing.

GitHub Actions rebuilds and checks release integrity, verifies that required runtime files are not ignored by Git, then runs installer and Lua lifecycle tests. Full QML / Qt checks require an Omarchy environment and run locally through `npm run check`. See the [desktop integration guide](tests/integration/README.md) for verification with actual official commands.

## Acknowledgments

Thanks to these projects for the underlying capabilities and design references:

- [Omarchy](https://github.com/omacom/omarchy): Plugin host, themes, translations, and workspace bar.
- [Hyprland](https://github.com/hyprwm/Hyprland): Window, workspace, and monitor management, plus Lua / IPC interfaces.
- [Quickshell](https://quickshell.org/) and [Qt](https://www.qt.io/): QML UI, Wayland integration, and live window capture.
- [Orbit](https://github.com/rohan-patnaik/orbit): Reference for an Omarchy switcher, MRU ordering, and input interaction.
- [Hyprspace](https://github.com/KZDKM/Hyprspace): Design reference for workspace overviews and window layout previews.
- [Hyprshell](https://github.com/H3rmt/hyprshell): Reference for application icon matching, window switching, and configuration interaction.

## License

This project is licensed under the [MIT License](LICENSE). Copyright © 2026 Jessie.
