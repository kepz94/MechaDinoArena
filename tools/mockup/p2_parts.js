const VOLT = 0x7fe9ff, BLOOD = 0xd0202a, LED = 0xffe7b0;
// ---------- parts: steps, looks, notes (Kepu 2026-10-31 picks) ----------
const PARTS = [
  {id: "siphon", name: "Blood Siphon", area: "HEALTH", key: "always on", steps: [
      "Heal 1 HP/s for each bleeding enemy within 15 studs", "1.5 HP/s each", "Range 25 studs", "A bleed kill near you heals 25% of your max health"],
    note: "On while slotted, no key. Counts any enemy that's bleeding (your slash bleed or anyone's). Uses the same heal path as Blood Drinker, so overheal turns into its shield when Blood Drinker ★ is bought.",
    looks: [
      {name: "A · Throat Pump", sub: "the red throat sac becomes a glowing blood tank", why: "The Herrera's red throat sac gets a glass tank with steel bands and a pump. You can watch red drops stream into it from bleeding enemies. It uses a body part it already has, so it reads at a glance.", parts: "Glass canister around the throat sac, glowing red core (it pulses on each heal), 2 steel bands, side pump."},
      {name: "B · Siphon Fangs", sub: "hollow steel fangs + tubes to a chest tank", why: "Two hollow steel fangs on the lower jaw, with red tubes running down the neck to a glass tank on the chest. It looks vampiric and mean.", parts: "2 jaw fangs, jaw brace, 2 glowing neck tubes, chest tank with a red core."}]},
  {id: "strobe", name: "Strobe Frill", area: "UTILITY", key: "R", steps: [
      "Frill flash in a 60° cone, 20 studs: enemies are dazed (can't attack) for 1 s", "Daze 1.5 s", "Cone 90°, 25 studs", "Dazed enemies also take +20% damage while dazed"],
    note: "Its own slot key, 16 s cooldown. It works on bots and players in front of you. Dazed = can't attack or use abilities (they can still move), with spinning stars over the head.",
    looks: [
      {name: "A · LED Frill", sub: "light strips along every frill spine", why: "Every spine of the frill gets a light strip, and the whole frill lights up white on the flash. It uses the Herrera's most iconic feature, so it's instantly recognizable.", parts: "22 light strips (both faces of the 11 spines), 11 rim lamps, steel neck collar."},
      {name: "B · Strobe Lamps", sub: "two big strobe lights mounted on the frill", why: "Two chunky strobe lamps on the sides of the frill, like a police light bar. They're easy to spot from far away and fire a bright double blink.", parts: "2 lamp housings with lenses, frill bracket, steel neck collar."}]},
  {id: "breaker", name: "Stun Breaker", area: "DEFENSE", key: "R", steps: [
      "Break out of a stun / pin", "Pushes nearby enemies back 10 studs", "Cooldown 14 s", "1 s of no damage after breaking out"],
    note: "Its own slot key, 20 s cooldown (14 s from III). It can only be used while you're stunned or pinned. Outside a stun the tile shows dimmed.",
    looks: [
      {name: "A · Tesla Crown", sub: "steel prongs with blue tips on every frill rim", why: "The frill tips become a crown of steel prongs with electric-blue tips. Bolts crackle out of all of them when you break free. It looks electric at a glance.", parts: "11 prongs with glowing tips on the frill rims, capacitor collar on the neck."},
      {name: "B · Back Capacitor", sub: "a capacitor box with two coil prongs on the hump", why: "A capacitor box on the hump with two tall coil prongs. The bolts arc out from the prongs. It's a clear piece of mecha gear that leaves the frill as it is.", parts: "Capacitor box, 2 coil prongs with rings and glowing tips, power cable."}]}];
const BOT_BITE = 20, SLASH = 8;
let part = 0, look = 0, step = 3, slotted = true, labView = false, slow = false;
