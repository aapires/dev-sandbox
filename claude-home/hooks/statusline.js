#!/usr/bin/env node
// statusline.js — barra de status do dev-sandbox.
// Mostra: modelo │ diretório │ uso da janela de contexto (absoluto + percentual).
// Script original, sem dependências (só built-ins do Node). Lê um JSON no stdin no
// formato do statusLine do Claude Code e escreve uma linha no stdout.
const path = require('path');

let input = '';
const timer = setTimeout(() => process.exit(0), 3000); // guarda contra stdin que não fecha
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  clearTimeout(timer);
  let d = {};
  try { d = JSON.parse(input); } catch { process.exit(0); }

  const dim = (s) => `\x1b[2m${s}\x1b[0m`;
  const model = d.model?.display_name || 'Claude';
  const dir = path.basename(d.workspace?.current_dir || d.cwd || '');

  let ctx = '';
  const cw = d.context_window || {};
  if (cw.remaining_percentage != null) {
    const total = cw.total_tokens || 1_000_000;
    const used = Math.max(0, Math.min(100, Math.round(100 - cw.remaining_percentage)));
    const usedTok = Math.round((total * used) / 100);
    const fmt = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(n % 1e6 ? 1 : 0)}M` : `${Math.round(n / 1000)}k`);
    const filled = Math.floor(used / 10);
    const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);
    const color = used < 50 ? '32' : used < 65 ? '33' : used < 80 ? '38;5;208' : '31';
    ctx = ` \x1b[${color}m${bar} ${used}% · ${fmt(usedTok)}/${fmt(total)}\x1b[0m`;
  }

  process.stdout.write(`${dim(model)}${dir ? ' │ ' + dim(dir) : ''}${ctx}`);
});
