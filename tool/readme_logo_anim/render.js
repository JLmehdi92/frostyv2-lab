const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
(async () => {
  const [mode, query, ws, hs, out, a5, a6, a7, a8, a9] = process.argv.slice(2);
  const W = +ws, H = +hs;
  const alpha = a9 === 'alpha';
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  page.on('pageerror', e => console.error('PAGEERROR', e.message));
  page.on('console', m => { if (m.type() === 'error' || m.text().startsWith('METRICS')) console.error('CONSOLE', m.text()); });
  await page.goto('file://' + path.resolve(process.env.SCENE) + '?' + query);
  await page.evaluate(async () => {
    await window.fontReady;
    await document.fonts.ready;
    if (!document.fonts.check(window.FONTSPEC)) throw new Error('wordmark font not loaded');
    window.init();
    console.log('METRICS ' + JSON.stringify(Object.assign({ vb: st.vb }, st.metrics)));
  });
  const transparent = query.includes('bg=none');
  const shot = async t => {
    await page.evaluate(tt => window.render(tt), t);
    const png = mode === 'stills' || transparent;
    return page.screenshot({ type: png ? 'png' : 'jpeg', quality: png ? undefined : 95, omitBackground: transparent, clip: { x: 0, y: 0, width: W, height: H } });
  };
  if (mode === 'stills') {
    fs.mkdirSync(out, { recursive: true });
    for (const t of a5.split(',').map(Number)) fs.writeFileSync(path.join(out, `t${t.toFixed(3).padStart(7, '0')}.png`), await shot(t));
  } else {
    const fps = +a5, dur = +a6, sub = +a7, shutter = +(a8 || 1);
    const avg = sub > 1 ? `tmix=frames=${sub}:weights=${Array(sub).fill(1).join(' ')},select='not(mod(n+1\\,${sub}))',setpts=N/(${fps}*TB)` : `setpts=N/(${fps}*TB)`;
    let args;
    if (alpha) {
      const vf = `format=gbrap,premultiply=inplace=1,${avg},unpremultiply=inplace=1,format=yuva420p`;
      args = ['-y', '-v', 'error', '-f', 'image2pipe', '-c:v', 'png', '-framerate', String(fps * sub), '-i', '-', '-vf', vf, '-r', String(fps),
        '-c:v', 'libvpx-vp9', '-pix_fmt', 'yuva420p', '-b:v', '0', '-crf', '24', '-row-mt', '1', '-auto-alt-ref', '0', out];
    } else {
      args = ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', String(fps * sub), '-i', '-', '-vf', avg + ',format=yuv420p', '-r', String(fps),
        '-c:v', 'libx264', '-preset', 'slow', '-crf', '14', '-tune', 'animation', '-movflags', '+faststart', out];
    }
    const ff = spawn('ffmpeg', args, { stdio: ['pipe', 'inherit', 'inherit'] });
    const nF = Math.round(dur * fps);
    const t0 = Date.now();
    for (let k = 0; k < nF; k++) {
      for (let j = 0; j < sub; j++) {
        const t = k / fps + (sub > 1 ? (j / (sub - 1) - 0.5) * shutter / fps : 0);
        const buf = await shot(Math.max(0, t));
        if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
      }
      if (k % 60 === 0) console.log(`${path.basename(out)} frame ${k}/${nF} ${((Date.now() - t0) / 1000).toFixed(0)}s`);
    }
    ff.stdin.end();
    await new Promise(r => ff.on('close', r));
  }
  await browser.close();
})();
