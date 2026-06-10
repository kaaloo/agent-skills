#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('Usage: validate-dsfr-stitch-output.mjs <html-or-md-files...>');
  process.exit(2);
}

const allowedHex = new Set([
  '#000091', '#6A6AF4', '#E1000F', '#FFFFFF', '#F6F6F6', '#EEEEEE', '#DDDDDD',
  '#666666', '#3A3A3A', '#161616', '#0063CB', '#18753C', '#B34000', '#CE0500',
  '#FFE9E9', '#E8EDFF', '#B8FEC9'
]);

const findings = [];
function add(file, severity, message) { findings.push({ file, severity, message }); }

for (const file of files) {
  let text;
  try {
    const stat = fs.statSync(file);
    if (!stat.isFile()) continue;
    text = fs.readFileSync(file, 'utf8');
  } catch (error) {
    console.error(`Error reading ${file}: ${error.message}`);
    continue;
  }
  const base = path.basename(file);
  const lower = text.toLowerCase();

  const isCodeArtifact = /\.(html|tsx|jsx|ts|js|mjs|cjs|vue|svelte)$/i.test(file);
  if (isCodeArtifact && /class(?:Name)?="[^"]*(?:\bp-|\bm-|\bgrid\b|\bflex\b|\brounded|\bshadow)/i.test(text)) {
    add(base, 'warning', 'Looks Tailwind/generic. Translate concepts to react-dsfr utilities and components before production.');
  }
  if (isCodeArtifact && /from ['"](?:@radix-ui|lucide-react|[^'"]*shadcn)|components\/ui\//i.test(text)) {
    add(base, 'error', 'shadcn/Radix/Lucide implementation pattern detected; not a DSFR production path.');
  }
  if (!/marianne/i.test(text)) add(base, 'warning', 'Marianne typography not found. Verify DSFR font handling in implementation.');
  if (!/république|republique|serviceTitle|brandTop/i.test(text)) add(base, 'warning', 'No République Française or DSFR service framing detected.');
  if (!/(<main\b|role=["']main["'])/i.test(text) && file.endsWith('.html')) add(base, 'warning', 'No main landmark detected in HTML.');
  if (/<input\b/i.test(text) && !/(<label\b|aria-label=|aria-labelledby=)/i.test(text)) add(base, 'error', 'Inputs detected without obvious labels.');
  if (/<img\b(?![^>]*\balt=)/i.test(text)) add(base, 'error', 'Image detected without alt attribute.');

  const hexes = [...new Set((text.match(/#[0-9a-fA-F]{6}\b/g) || []).map((h) => h.toUpperCase()))];
  for (const hex of hexes) {
    if (!allowedHex.has(hex)) add(base, 'warning', `Non-starter DSFR hex found: ${hex}. Verify against DSFR tokens or justify exception.`);
  }

  if (/gradient|glassmorphism|neon|cyberpunk|drop-shadow|shadow-xl/i.test(lower)) {
    add(base, 'warning', 'Decorative AI style cue detected. DSFR concepts should stay restrained and operational.');
  }
}

console.log(JSON.stringify({ findings, summary: {
  errors: findings.filter((f) => f.severity === 'error').length,
  warnings: findings.filter((f) => f.severity === 'warning').length,
}}, null, 2));
process.exit(findings.some((f) => f.severity === 'error') ? 1 : 0);
