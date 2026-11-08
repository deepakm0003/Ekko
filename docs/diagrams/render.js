// Render the SVG diagrams to 2x PNG. Usage: node render.js <dir> (needs `sharp`).
const fs = require("fs");
const path = require("path");
const sharp = require("sharp");

const dir = process.argv[2] || __dirname;
(async () => {
  for (const f of fs.readdirSync(dir).filter((n) => n.endsWith(".svg"))) {
    const out = path.join(dir, f.replace(/\.svg$/, ".png"));
    await sharp(path.join(dir, f), { density: 144 }).png().toFile(out);
    console.log("rendered", out);
  }
})();
