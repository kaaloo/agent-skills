#!/usr/bin/env node
import process from 'node:process';

const url = process.env.STITCH_HOST || 'https://stitch.googleapis.com/mcp';
const [command, maybeTool, maybeJson] = process.argv.slice(2);

function usage() {
  console.error(`Usage:
  stitch-mcp.mjs list-tools
  stitch-mcp.mjs list-projects
  stitch-mcp.mjs info <tool>
  stitch-mcp.mjs call <tool> '<json>'

Auth:
  STITCH_API_KEY for API key auth, or STITCH_ACCESS_TOKEN plus GOOGLE_CLOUD_PROJECT for OAuth.`);
}

function authHeaders() {
  if (process.env.STITCH_API_KEY) return { 'X-Goog-Api-Key': process.env.STITCH_API_KEY };
  if (process.env.STITCH_ACCESS_TOKEN) {
    const headers = { Authorization: `Bearer ${process.env.STITCH_ACCESS_TOKEN}` };
    const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.STITCH_PROJECT_ID;
    if (project) headers['X-Goog-User-Project'] = project;
    return headers;
  }
  throw new Error('Missing STITCH_API_KEY or STITCH_ACCESS_TOKEN.');
}

async function parseResponse(res) {
  const text = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 800)}`);
  const type = res.headers.get('content-type') || '';
  if (type.includes('text/event-stream')) {
    const lines = text.split('\n').filter((line) => line.startsWith('data: ')).map((line) => line.slice(6));
    for (let i = lines.length - 1; i >= 0; i--) {
      try {
        const parsed = JSON.parse(lines[i]);
        if (parsed.jsonrpc === '2.0') return parsed;
      } catch {}
    }
    throw new Error('No JSON-RPC response in SSE stream.');
  }
  return JSON.parse(text);
}

async function rpc(method, params, headers, id) {
  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify({ jsonrpc: '2.0', id, method, params }),
  });
  return { parsed: await parseResponse(res), session: res.headers.get('Mcp-Session-Id') };
}

async function notifyInitialized(headers) {
  await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} }),
  });
}

async function main() {
  if (!command) { usage(); process.exit(2); }

  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json, text/event-stream',
    ...authHeaders(),
  };

  const init = await rpc('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'dsfr-stitch-skill', version: '0.1.0' },
  }, headers, 1);
  if (init.session) headers['Mcp-Session-Id'] = init.session;
  if (init.parsed.error) throw new Error(init.parsed.error.message);
  await notifyInitialized(headers);

  if (command === 'list-tools') {
    const { parsed } = await rpc('tools/list', {}, headers, 2);
    if (parsed.error) throw new Error(parsed.error.message);
    for (const tool of parsed.result.tools) console.log(`${tool.name}\t${tool.description || ''}`);
    return;
  }

  if (command === 'list-projects') {
    const { parsed } = await rpc('tools/call', { name: 'list_projects', arguments: { filter: 'view=owned' } }, headers, 3);
    if (parsed.error) throw new Error(parsed.error.message);
    console.log(JSON.stringify(parsed.result, null, 2));
    return;
  }

  if (command === 'info') {
    if (!maybeTool) { usage(); process.exit(2); }
    const { parsed } = await rpc('tools/list', {}, headers, 4);
    if (parsed.error) throw new Error(parsed.error.message);
    const tool = parsed.result.tools.find((item) => item.name === maybeTool);
    if (!tool) throw new Error(`Tool not found: ${maybeTool}`);
    console.log(JSON.stringify(tool, null, 2));
    return;
  }

  if (command === 'call') {
    if (!maybeTool) { usage(); process.exit(2); }
    let args = {};
    if (maybeJson) {
      try {
        args = JSON.parse(maybeJson);
      } catch (error) {
        console.error(`Error: Invalid JSON arguments: ${error.message}`);
        process.exit(1);
      }
    }
    const { parsed } = await rpc('tools/call', { name: maybeTool, arguments: args }, headers, 5);
    if (parsed.error) throw new Error(parsed.error.message);
    console.log(JSON.stringify(parsed.result, null, 2));
    return;
  }

  usage();
  process.exit(2);
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exit(1);
});
