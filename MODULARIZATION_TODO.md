# Power Ranger ON Modularization TODO

Keep this local checklist ignored by git. It tracks cleanup work without shipping it with the addon.

## Remaining Runtime Splits

- Move ownership labels for housing, boats, mounts, and vehicles into a small ownership overlay module.
- Move cooldown settings rows and recipe editor helpers out of the main settings section file.
- Move skill/event probe runtime into a detector module with explicit start/stop cleanup.
- Finish extracting target intel rendering from target_overlay into target_windows.
- Add class-based target intel window support for role-specific layouts and stat priorities.
- Finish extracting model target overhead runtime from target_overlay into its own overlay module.
- Centralize default settings and migration in one settings module.
- Add a final init/cleanup pass so all modules expose consistent OnLoad, OnUpdate, and OnUnload hooks.

## Guardrails

- Keep each Lua file below the local variable limit.
- After every slice, reload in-game and run `git diff --check`.
- Preserve current behavior first; improve layout only after the split is stable.
