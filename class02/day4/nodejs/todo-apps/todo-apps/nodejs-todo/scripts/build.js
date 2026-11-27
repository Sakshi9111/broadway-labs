// A tiny "build" step: it copies the app into dist/ and stamps it with build info.
const fs = require("fs");
const path = require("path");
const pkg = require("../package.json");

const root = path.join(__dirname, "..");
const dist = path.join(root, "dist");

console.log("1/3 cleaning dist/");
fs.rmSync(dist, { recursive: true, force: true });

console.log("2/3 copying src/ and public/ into dist/");
fs.cpSync(path.join(root, "src"), path.join(dist, "src"), { recursive: true });
fs.cpSync(path.join(root, "public"), path.join(dist, "public"), { recursive: true });

console.log("3/3 writing dist/build-info.json");
fs.writeFileSync(
  path.join(dist, "build-info.json"),
  JSON.stringify({ name: pkg.name, version: pkg.version, builtAt: new Date().toISOString(), node: process.version }, null, 2)
);

console.log("Build complete. Run it with: npm start");
