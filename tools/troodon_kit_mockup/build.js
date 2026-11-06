// Troodon kit mockup v0.1: head.html + three.js r128 (inline) + model data + engine (dilo kit mockup v0.1's, lines 5-275) + app part
const fs = require("fs"), path = require("path");
const D = __dirname;
const three = fs.readFileSync(process.env.THREE || path.join(D, "three.min.js"), "utf8").trim();
const out = fs.readFileSync(path.join(D, "head.html"), "utf8") +
  "<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n/**\n * @license\n * Copyright 2010-2021 Three.js Authors\n * SPDX-License-Identifier: MIT\n */\n" + three + "\n</script>\n<script>\n" +
  "// TROODON = src/shared/Models/TroodonModelData.luau 1.0 (tools/troodon_generator.py --look B --json); RAPTOR = model_json export (enemies + squadmate).\n" +
  "const TROODON = " + fs.readFileSync(path.join(D, "troodonB.json"), "utf8").trim() + ";\nconst RAPTOR = " + fs.readFileSync(path.join(D, "../dilo_kit_mockup/raptor.json"), "utf8").trim() + ";\n" +
  fs.readFileSync(path.join(D, "engine_part.js"), "utf8") + "\n" + fs.readFileSync(path.join(D, "app_tail.js"), "utf8") + "\n</script>\n</body>\n</html>\n";
const dest = process.argv[2] || path.join(D, "../../docs/mockups/troodon_kit_options_v0.1.html");
fs.writeFileSync(dest, out); console.log(dest, out.length);
