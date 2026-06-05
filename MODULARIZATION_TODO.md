# Power Ranger ON Modularization TODO

Keep this local checklist ignored by git. It tracks cleanup work without shipping it with the addon.

## Remaining Runtime Splits

- Move ownership labels for housing, boats, mounts, and vehicles into a small ownership overlay module.
- Move cooldown settings rows and recipe editor helpers out of the main settings section file.
- Move skill/event probe runtime into a detector module with explicit start/stop cleanup.
- Finish extracting target intel rendering from target_overlay into target_windows.
- Finish extracting model target overhead runtime from target_overlay into its own overlay module.
- Centralize default settings and migration in one settings module.
- Add a final init/cleanup pass so all modules expose consistent OnLoad, OnUpdate, and OnUnload hooks.

## Critical (do before adding any new target_overlay feature)

- [ ] `target_overlay.lua` is at ~183/200 main-chunk locals (was 188 before the skill_probe slice). Extract before adding features; overflowing the cap silently breaks the whole overlay and looks like "settings are gone".
- CORRECTION: `serialValue`/`recordSkillProbe`/`recordDetectedSkill`/`refreshSettingsButtons`/`refreshDetectedSkillRows` are NOT accidental globals — they are forward-declared locals (target_overlay.lua:313-318) injected into sub-modules via the `ctx` table pattern. No env leak. They still each cost a local slot, so the relief comes from moving their bodies into modules (and dropping the forward decl), not from a global rename.

## Done (all NEED in-game `/reload` verification before building further)

- [x] Slice 1: extracted pure probe-text helpers (`serialValue`, `probeText`, `hasProbeKeyword`, keyword tables) into `skill_probe.lua`. target_overlay 188 -> 183 locals.
- [x] Slice 2: extracted Hot Swap aura matching + auto-trigger predicates (custom-aura model, `readPlayerAuras`, `anyAuraMatches`, swimming/sleep/wakeup) into `hot_swap_auras.lua`. hot_swap 1555 -> 1419 lines. Pure functions only; `ensureAutoSettings` (settings-coupled) deliberately stayed. Names bound back to identical locals = zero call-site churn (hot_swap is far from the local cap, so binding is fine there).
- [x] Slice 3: extracted pure detection predicates (`auraLooksLikeCooldownSkill`, `detectedSkillKey`) into `skill_probe.lua`. target_overlay 183 -> 181 locals. Call sites rewritten to `SkillProbe.*` (NOT bound to locals) because target_overlay IS near the cap, so binding would give no relief.
- [x] Slice 4: extracted stateless parsers (`detectFallbackSkillName`, `parsedCombatMessage`, `extractSkillFields`) into `skill_probe.lua` (now requires `overlay_utils`). Removed the orphaned `unpackArgs` local. target_overlay 181 -> 177 locals. `skill_probe.lua` now owns ALL stateless probe/detection/parse helpers; only the stateful runtime remains in target_overlay.

CUMULATIVE: target_overlay 188 -> 177 main-chunk locals; hot_swap 1555 -> 1419 lines. 3 new modules: `skill_probe.lua`, `hot_swap_auras.lua`.

## Next slice (do AFTER a reload checkpoint)

- [ ] Move the stateful probe runtime (`auraSnapshot`, `probeSnapshot`, `recordSkillProbe`, `recordDetectedSkill`, `detectFrom*`, `updateProbeLogging`, combat/skill event handlers) into `skill_probe.lua` via the established `ctx` injection pattern. This also has to relocate or inject module state (`skillProbe`, `skillProbeDirty`, `probeLogElapsed`, `detectManaState`). Higher risk -- do not stack on top of unverified slices.

## New surfaces (added since this list was written)

- [ ] Split `hot_swap.lua` (1,555 lines): separate loadout data/migration, auto-trigger runtime, gear view, and settings window into sub-modules. It is a second monolith and was not in the original list.
- [ ] Decide single ownership of cooldown defaults across `cooldown_catalog`, `nuzi_cooldown_import`, and `cooldown_recipes`.
- [ ] Give the skill-probe/detector path explicit start/stop tied to `refreshEventSubscriptions`.

## De-duplication

- [ ] Replace `hot_swap.lua`'s own `label`/`flatButton`/`panel`/`darkEdit` with `ui_helpers.*`.
- [ ] Replace `hot_swap.lua`'s own `safeCall`/`clamp`/`trim`/`lower` with `overlay_utils.*`.
- [ ] Drop the thin wrapper locals in `target_overlay` (`label`, `flatButton`, `panel`, `sectionPanel`, `colorCube`, `addBg`, `setToggleButton`) once call sites move to `uiHelpers.*`, to reclaim main-chunk local slots.

## Contract

- [ ] Write the module contract (Create/init/update/cleanup + OnLoad/OnUpdate/OnUnload) into this file and make every existing module conform, not just new ones.

## Guardrails

- Keep each Lua file below the local variable limit.
- After every slice, reload in-game and run `git diff --check`.
- Preserve current behavior first; improve layout only after the split is stable.
