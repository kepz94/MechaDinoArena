// Camera options mockup v0.1: head.html + three.js r128 (inlined) + app.js + tail.html -> docs/mockups/camera_options_v0.1.html
// Run: THREE=/path/to/three.min.js node tools/camera_mockup/build.js [out.html]
const fs = require("fs"), path = require("path");
const D = __dirname;
const threePath = process.env.THREE || path.join(D, "three.min.js");
const three = fs.readFileSync(threePath, "utf8").trim();
const out = fs.readFileSync(path.join(D, "head.html"), "utf8") + fs.readFileSync(path.join(D, "tail.html"), "utf8") +
  "<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n" + three + "\n</script>\n<script>\n" +
  fs.readFileSync(path.join(D, "app.js"), "utf8") + "\n</script>\n</body>\n</html>\n";
const dest = process.argv[2] || path.join(D, "../../docs/mockups/camera_options_v0.1.html");
fs.writeFileSync(dest, out);
console.log(dest, out.length);
