// assembles the single-file mockup: head.html + three.js r128 (inline, as in the template) + model data + app.js
const fs = require("fs"), path = require("path");
const D = __dirname;
const head = fs.readFileSync(path.join(D, "head.html"), "utf8");
const three = fs.readFileSync(path.join(D, "three.min.js"), "utf8").trim();
const dilo = fs.readFileSync(path.join(D, "diloE.json"), "utf8").trim();
const rap = fs.readFileSync(path.join(D, "raptor.json"), "utf8").trim();
const app = fs.readFileSync(path.join(D, "app.js"), "utf8");
const out = head +
  "<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n/**\n * @license\n * Copyright 2010-2021 Three.js Authors\n * SPDX-License-Identifier: MIT\n */\n" + three + "\n</script>\n<script>\n" +
  "// DILO = src/shared/Models/DiloModelData.luau 1.0 (tools/dilo_generator.py --json, look E Bruiser Face); RAPTOR = model_json export (target).\n" +
  "const DILO = " + dilo + ";\nconst RAPTOR = " + rap + ";\n" + app + "\n</script>\n</body>\n</html>\n";
const dest = process.argv[2] || "/home/claude/mechadinoarena/docs/mockups/dilo_kit_options_v0.1.html";
fs.writeFileSync(dest, out);
console.log(dest, out.length);
