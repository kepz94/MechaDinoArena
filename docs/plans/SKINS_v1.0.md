# Mecha Dino Arena — Skins v1.0: pick a dino skin in the Lab (menu only)

**Goal:** players choose a colour skin for their dino in the Lab's new SKINS tab (opened from the main menu), see it on their dino right away, and spawn in it every time until they pick another. First step of cosmetics (buying with Robux is the next plan).
**Intent (Kepu 2026-10-30):** "i want this to be a big part of our dinos because it will help with monetizing the game with skins and accessories" · "it should recolour in the menu when you select the skin you want to attach not in spawn" · "whatever is chosen in the menu is what youre spawning with every time unless you choose a different skin" · "the skins locker belongs in the lab with the other tab" · Robux: "Skins first, buying next" · island: "menu only".
**Chosen direction:** mockup `docs/mockups/skins_lab_tab.html` — SKINS as the Lab's third tab (MECHA ABILITIES · STATS · SKINS), full Lab only. (Earlier menu-picker mockup `docs/mockups/skins_menu_options.html` superseded by Kepu's "belongs in the lab".)
**Architecture:** a colour-role palette swap. Each dino's blocks already share a few authored colours (raptor: main `5E943E` ×23, bands `283A1E` ×25, claws `302824` ×14, limbs `8FA046` ×8, belly `C9C98F` ×7, stripe `2E8C82` ×2, eyes `F0C81E` ×2; T-Rex: main `666A4A` ×20, dark `50523A` ×14, belly `B2A278` ×9). On every new body (default colours) SkinServer tags each visible block with its role (`SkinRole`) by that authored colour, then paints the equipped skin. Clients recolour preview copies from the same `SkinRole` tags. Model data, the builder and the generators are not changed.

## Global constraints
- Additive only; every new behaviour behind a switch attribute; versions: SkinCatalog 1.0, SkinServer 1.0, Lab 1.6, MainMenu 1.7, ArenaScope 1.17 (header + changelog, VERSION, docs/VERSIONS.md, docs/ATTRIBUTES.md).
- Colours (and optional Material) only: never Size, CFrame, CanCollide, hitboxes, attributes other than the skin ones. Mecha_* models, HumanoidRootPart, `Hitboxes`, eyes' pupils, teeth and mouth are never repainted.
- Equipping is only allowed while the player is in the menu (`InMenu == true`); the island Lab (compact) has no SKINS tab.
- Each species has its own skins; the equipped skin is saved per species.
- v1 ownership: skins with `free = true` are owned by everyone; the rest show a price and "GET · R$n" greyed (buying = next plan).
- Install by multi_edit + hash + loadstring check; Studio play tests from the default camera; Kepu publishes.

## Do-not-touch
DinoModelBuilder, RaptorModelData / TRexModelData and their generators, SpeciesServer, the StarterCharacter T-Rex model, BotServer (bots stay classic), CloakFX (records colours when a cloak starts — skins are painted at spawn / in the menu, before any cloak), DeadPose (copies the head colour to the eyes and puts it back — works with any skin), LabPreviewServer, SkillServer saves.

## Skins in v1
| Species | id | Name | Rarity | Price shown | Free | main · bands · limbs · belly · claws · stripe · eyes |
|---|---|---|---|---|---|---|
| Raptor | classic | Classic | STARTER | — | yes | 5E943E · 283A1E · 8FA046 · C9C98F · 302824 · 2E8C82 · F0C81E |
| Raptor | desert | Desert Runner | COMMON | — | yes | C9A46A · 7A5530 · B08A55 · EBDDB8 · 3B2A1C · C2552E · F0C81E |
| Raptor | arctic | Arctic | RARE | 149 | no | E6EEF3 · 7FA6C2 · C7D8E3 · FFFFFF · 3A4A57 · 3FB4E6 · 7FE9FF |
| Raptor | night | Night Stalker | RARE | 149 | no | 22262B · 0E1012 · 33393F · 4A5058 · 0B0C0D · 5FD16A · 5FD16A (stripe, eyes Neon) |
| Raptor | lava | Lava | EPIC | 299 | no | 2E2524 · FF6A1A · 3D302E · 5A3A30 · 120D0C · FFC832 · FF6A1A (bands, stripe, eyes Neon) |
| Raptor | gold | Gold Hunter | LEGENDARY | 499 | no | D4A72C · 7A5A10 · E6C25A · F5E4A8 · 3A2A08 · FFF2B0 · FFFFFF (stripe, eyes Neon) |
| TRex | classic | Classic | STARTER | — | yes | main 666A4A · dark 50523A · belly B2A278 |
Prices are placeholders shown on locked cards; Kepu sets real prices in the buying plan.

## Tasks

### Task 1 — SkinCatalog 1.0 + spec · Mode: Logic
**Files:** Create `src/shared/SkinCatalog.luau` (ServerStorage.DinoArcade.SkinCatalog), `tools/tests/SkinCatalog.spec.luau`.
**Interfaces (produces):**
- `SkinCatalog.Version = "1.0"`
- `SkinCatalog.ROLES[species] = {[hex] = role}` (authored colour → role; hex upper-case, no #).
- `SkinCatalog.SKINS[species] = { {id, name, rarity, price (number|nil), free (bool), colors = {[role] = hex}, materials = {[role] = "Neon"|...}|nil} }` in display order; first entry = default.
- `SkinCatalog.roleOf(species, color3) -> role | nil` (exact match of `color3:ToHex():upper()`).
- `SkinCatalog.get(species, id) -> skin | nil`; `SkinCatalog.default(species) -> id`.
- `SkinCatalog.owns(species, id, ownedSet) -> bool` (free, or `ownedSet[id] == true`).
- `SkinCatalog.sanitize(species, id) -> id` (unknown / nil → default).
- `SkinCatalog.paint(species, id, part, role)` is NOT here (pure module; painting lives in the scripts).
**Steps:** write the spec first (roles of every authored raptor / T-Rex colour, unknown colour → nil, Classic colours == authored colours for every role, sanitize, owns with free / owned / locked, every skin has a colour for every role of its species); run it in Studio (execute_luau, fails); write the module; run → PASS; commit.
**Acceptance:** spec PASS; Classic paints back exactly the authored colours (round trip); every SKINS colour is valid hex; every authored colour is either a role or in `SkinCatalog.NEVER_PAINT` (spec reads RaptorModelData and, for the T-Rex, the StarterCharacter: TRexModelData is not installed in Studio); no Instance access in the module.

### Task 2 — SkinServer 1.0 · Mode: Wired
**Files:** Create `src/server/SkinServer.server.luau` (ServerScriptService).
**Interfaces:** consumes SkinCatalog. Produces: RemoteEvent `ReplicatedStorage.DinoSkinRequest:FireServer("equip", skinId)`; a copy of SkinCatalog at `ReplicatedStorage.SkinShared` (as SkillServer does with SkillShared); player attributes `SkinEquipped_<Species>` (id), `SkinOwnedFree` (comma ids, v1), `SkinSaveState`; character attributes `SkinApplied` (id, set last), `SkinParts` (count painted); part attribute `SkinRole`.
**Steps:**
1. Persistence (the assignment stays until the player picks another skin):
   - DataStore `MDA_Skins_v1`, key `u<UserId>`, value `{v = 1, equipped = {[species] = id}, owned = {}}` (`owned` reserved for the buying plan; v1 never writes into it, it only carries it through).
   - Load on join with `GetAsync`, up to LOAD_TRIES (3) attempts LOAD_GAP (2, then 4) s apart. Loaded / new -> `SkinSaveState` "loaded" / "new". All attempts failed -> "loadFailed": the player plays with the default, equips still work for this session, and **nothing is ever written for that player this session** (a failed load can never overwrite a stored skin or a future purchase); the load is retried every RETRY_GAP (30) s and a later success applies the stored skin. Studio without API access -> "noApi" (same no-write rule).
   - Save with `UpdateAsync` (merge: only `equipped[species]` is replaced; `owned` and other species are kept from the stored value), SAVE_GAP (6) s after a change, on PlayerRemoving, and in `game:BindToClose` (server shutdown), each in pcall with one retry; `SkinSaveState` "saved" / "saveFailed" (retried next gap).
   - Studio testing: with Kepu's Game Settings → Security → "Enable Studio Access to API Services" on, the save / load path is tested in Studio (rejoin keeps the skin); without it, Kepu checks it live after publishing.
2. On every new character (CharacterAdded, also the raptor swap SpeciesServer does): wait for the body's parts, tag each BasePart that is not HumanoidRootPart, not in `Hitboxes`, not under a `Mecha_*` model, with `SkinRole = SkinCatalog.roleOf(species, part.Color)` (only when the role exists and the part has no SkinRole yet), then paint the equipped skin (`Color`, and `Material` when the skin gives one, else the part's own). Set `SkinApplied` last.
3. `equip`: checks in order "badArg" (not a string), "notInMenu" (InMenu ~= true), "unknown" (not in this species' SKINS), "locked" (not owned), "same", "ok" → paint the live (parked) character, set `SkinEquipped_<Species>`, queue a save. Result in player attribute `SkinServerResult`.
4. Switch `SkinServerEnabled` (default true; false = no tags, no paint, remote ignored).
**Acceptance:** fresh raptor gets 81 SkinRole tags (bands 25, main 23, claws 14, limbs 8, belly 7, stripe 2, eyes 2), a fresh T-Rex 43 (main 20, dark 14, belly 9); equip "desert" in the menu → live dino recolours, `SkinApplied` "desert"; die and respawn → still desert; switch to T-Rex and back → raptor still desert; equip on the island → "notInMenu"; locked skin → "locked"; Mecha parts, hitboxes, teeth, pupils unchanged; Cloak on a skinned raptor fades and comes back in the skin colours; DeadPose eyes still take the head colour.

### Task 3 — Lab 1.6 SKINS tab · Mode: Wired
**Files:** Modify `src/client/Lab.client.luau`.
**Interfaces:** consumes `ReplicatedStorage.SkinShared` (SkinCatalog), part `SkinRole`, player `SkinEquipped_<Species>`, `SkinServerResult`, `DinoSkinRequest`.
**Layout (from the mockup):** tabs row MECHA ABILITIES · STATS · SKINS (three equal tabs, SKINS stroke `#c9a2ff` when on) — full Lab only; compact keeps two tabs. Grid: the same 2-column cards; card = 4:3 ViewportFrame with a plain copy of your character (no Mecha_*) painted in that skin, name (FredokaOne), rarity (mono, rarity colour: STARTER/COMMON grey, RARE volt, EPIC `#c9a2ff`, LEGENDARY yellow), top-right badge "ON" (equipped) or "R$n" (locked, green `#00b06f`). Stage tag "PREVIEW" while the SKINS tab is open; the stage copy is painted in the selected skin (restored to the equipped one when you leave the tab). Right panel: "<SPECIES> SKIN · <RARITY>", name, the skin's colour chips, a line ("Owned. Equip it and you spawn in it every time." / "Locked."), button EQUIP (`#c9a2ff`) / EQUIPPED (dark, disabled) / GET · R$n (green, disabled, "Buying comes in the next step."). Toast "<NAME> EQUIPPED" on `SkinServerResult` "ok".
**Steps:** add the tab (switch `LabSkinsEnabled`, default true, read at start); cards; stage paint; detail; EQUIP fires the remote; LabTab gains "skins"; diagnostics `LabSkinSelected`, `LabSkinCards`.
**Acceptance:** tab only in the full Lab; selecting cards previews on the stage without changing the real dino; EQUIP recolours the real dino (seen in the menu hangar after closing the Lab); locked button disabled; phone layout fits (three tabs readable at the smallest phone height); other tabs unchanged.

### Task 4 — MainMenu 1.7 · Mode: Wired
**Files:** Modify `src/client/MainMenu.client.luau`: re-copy the hangar preview when the character's `SkinApplied` changes (as it does for Species / Mecha_* changes). Switch `MainMenuSkinRecopyEnabled`.
**Acceptance:** after EQUIP in the Lab and closing it, the hangar dino shows the new skin at once.

### Task 5 — ArenaScope 1.17 · Mode: Wired
Expect SkinServer on. **Acceptance:** `ArenaScope_SkinServer` "on", mismatches 0.

## Deterministic map (SkinServer)
| Condition | Result |
|---|---|
| New body, no saved skin for its species | paint the default (Classic = authored colours, no visible change) |
| New body, saved skin known + owned | paint it |
| New body, saved skin unknown (removed from catalog) or no longer owned | paint default, keep the save untouched |
| equip, not in menu | "notInMenu", nothing changes |
| equip, unknown id | "unknown" |
| equip, locked | "locked" |
| equip, already equipped | "same" |
| equip ok | live body painted, attribute set, save queued |
| DataStore unavailable (Studio / outage) | SkinSaveState "noApi" / "loadFailed": play with the default, no writes this session until a retry loads the stored value |
| Server shuts down | BindToClose saves every changed player (merge) |
| Player picks Classic | Classic is stored like any skin (= "unassigned", the default look) |
| Part colour has no role (teeth, pupils, mouth, a future part) | left as it is |

## Red-team (Kepu's answers 2026-10-30)
1. Bright / Neon skins change how visible a dino is (Neon can glow through the 1% cloak; dark skins hide better): **accepted** — Kepu: "dont worry about being neon or whatnot this is an arcade game". Neon stays on Lava / Night Stalker / Gold Hunter.
2. A failed load followed by a save could wipe stored skins (and later purchases): **mitigated** — no writes after a failed load, UpdateAsync merge, `owned` carried through, BindToClose (Task 2 step 1). Kepu: "is there no way to assign a skin to a dino and keep it that way until unassigned? ... i cant do that if youre not sure" -> the assignment is a saved per-species value, applied to every new body; Classic = unassigned.
3. Studio blocks DataStores by default: **mitigated** — Kepu can turn on Studio API access so the save path is tested in Studio; otherwise a live rejoin check after publishing (acceptance).
4. Colour-matched roles break if a model colour changes: **mitigated** — the SkinCatalog spec checks that every authored colour in both model data files has a role or is on the never-paint list (teeth E8E2D2, pupils / T-Rex eyes 111111, mouths 963C3C / 6E342E, T-Rex shine F5F5F0, HumanoidRootPart A3A2A5).
