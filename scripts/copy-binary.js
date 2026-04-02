#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");

const ARCH_MAP = {
  arm64: "aarch64",
  x64: "x86_64",
};

const PLATFORM_MAP = {
  darwin: "darwin",
  linux: "linux",
};

const arch = ARCH_MAP[os.arch()];
const platform = PLATFORM_MAP[os.platform()];

if (!arch || !platform) {
  console.error(`Unsupported platform: ${os.platform()}-${os.arch()}`);
  process.exit(1);
}

const src = path.join(
  __dirname,
  "..",
  "_build",
  "native",
  "debug",
  "build",
  "cmd",
  "main",
  "main.exe"
);
const destDir = path.join(__dirname, "..", "dist", "artifacts");
const dest = path.join(destDir, `claude-watchdog-${arch}-${platform}`);

fs.mkdirSync(destDir, { recursive: true });
fs.copyFileSync(src, dest);
fs.chmodSync(dest, 0o755);

console.log(`Copied binary to ${path.relative(process.cwd(), dest)}`);
