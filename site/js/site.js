/* ONSET landing page behaviour. Plain JS; GSAP, ScrollTrigger and Lenis are optional. */
(function () {
  'use strict';

  var w = window;
  var doc = document;
  var html = doc.documentElement;
  var root = doc.querySelector('.page');
  // boot.js reads this flag on load: without it, it falls back to the no-script layout.
  html.classList.add('js', 'js-ready');
  // The boot failsafe may already have shown the page on a slow network: then nothing replays its entrance.
  var revealedEarly = !html.classList.contains('pre');
  if (!root) { html.classList.remove('pre'); return; }

  // Every visible string lives in the page's HTML. The only text this script writes is the LIVE
  // delay readout, so a page in another language sets its number format in a JSON block
  // (<script type="application/json" id="i18n">, which the browser never runs, so the CSP allows it).
  var L = { decimal: '.', unit: 's' };
  try {
    var cfg = doc.getElementById('i18n');
    if (cfg) {
      var o = JSON.parse(cfg.textContent);
      for (var k in L) { if (typeof o[k] === 'string') L[k] = o[k]; }
    }
  } catch (e) {}
  var fmtDelay = function (v) { return String(v).replace('.', L.decimal) + L.unit; };

  var S = { theme: 'dark', lat: null, index: null, heroOn: true };
  // No reduced-motion branch anywhere: the OS "reduce motion" setting (Windows "animation effects"
  // included) is ignored on purpose, because the owner decided that every visitor sees the motion.
  var finePointer = !!(w.matchMedia && w.matchMedia('(hover: hover) and (pointer: fine)').matches);
  var car = null;
  var drift = [];
  var fieldStart = null;
  var fieldStop = null;
  var latBack = null;

  var unhold = function () { html.classList.remove('pre'); };

  /* ---------- view state (what the page re-renders when its state changes) ---------- */
  var lvN = doc.getElementById('lv-n');
  var giftBody = doc.getElementById('gift-body');
  var carEl = doc.querySelector('.car');
  var capEls = Array.prototype.slice.call(doc.querySelectorAll('.caps .cap'));
  var dotEls = Array.prototype.slice.call(doc.querySelectorAll('.dots .dot'));

  var setLat = function (v) {
    S.lat = v;
    if (lvN) lvN.textContent = fmtDelay(v);
  };
  var setGiftOpen = function (open) {
    if (giftBody) giftBody.classList.toggle('is-open', !!open);
  };
  var setIndex = function (i) {
    S.index = i;
    if (carEl) carEl.classList.toggle('is-wide', i === 4);
    capEls.forEach(function (c, k) {
      c.classList.toggle('is-on', k === i);
      c.setAttribute('aria-hidden', k === i ? 'false' : 'true');
    });
    dotEls.forEach(function (d, k) {
      d.classList.toggle('is-on', k === i);
      d.setAttribute('aria-current', k === i ? 'true' : 'false');
    });
  };

  /* ---------- theme: dark by default, light on toggle ---------- */
  var themeT = 0;
  var tgl = doc.querySelector('.tgl');
  var themeMetas = Array.prototype.slice.call(doc.querySelectorAll('meta[name="theme-color"]'));
  var schemeMeta = doc.querySelector('meta[name="color-scheme"]');
  if (tgl) {
    tgl.addEventListener('click', function () {
      var light = S.theme === 'light';
      S.theme = light ? 'dark' : 'light';
      root.classList.add('theming');
      root.classList.toggle('theme-light', !light);
      tgl.setAttribute('aria-pressed', light ? 'false' : 'true');
      var bg = light ? '#0A0A0A' : '#F8F8F8';
      try {
        doc.body.style.transition = 'background-color .3s ease';
        doc.body.style.backgroundColor = bg;
      } catch (e) {}
      themeMetas.forEach(function (m) { m.setAttribute('content', bg); });
      if (schemeMeta) schemeMeta.setAttribute('content', light ? 'dark' : 'light');
      if (themeT) clearTimeout(themeT);
      themeT = setTimeout(function () { root.classList.remove('theming'); }, 380);
    });
  }

  /* ---------- carousel: 1:1 drag, velocity projection, critically damped snap ---------- */
  var initCarousel = function () {
    var vp = doc.getElementById('car-vp');
    var track = doc.getElementById('car-track');
    if (!vp || !track) return;
    // If the no-script layout was shown first, the viewport may have been scrolled natively.
    vp.scrollLeft = 0;
    var capsEl = doc.querySelector('.caps');
    var dotsEl = doc.querySelector('.dots');
    var slides = Array.prototype.slice.call(track.querySelectorAll('.slide'));
    var ins = slides.map(function (s) { return s.querySelector('.sl-in'); });
    var scr = slides.map(function (s) { return Array.prototype.slice.call(s.querySelectorAll('.screen, .tab-scr')); });
    var n = slides.length;
    var C = { x: 0, v: 0, target: 0, idx: 0, centers: [], vpW: 0, pitch: 400, anim: false, raf: 0, last: 0,
      down: false, drag: false, sx: 0, sy: 0, x0: 0, pid: null, hist: [], touched: false, visible: true, hover: false, focus: false };

    var offsetFor = function (i) { return C.vpW / 2 - C.centers[i]; };
    var render = function () {
      track.style.transform = 'translate3d(' + C.x.toFixed(2) + 'px,0,0)';
      for (var i = 0; i < n; i++) {
        var d = (C.centers[i] + C.x - C.vpW / 2) / C.pitch;
        var a = Math.min(Math.abs(d), 1.6);
        ins[i].style.transform = 'scale(' + (1 - a * 0.08).toFixed(4) + ')';
        var br = 'brightness(' + (1 - Math.min(a, 1) * 0.55).toFixed(3) + ')';
        for (var j = 0; j < scr[i].length; j++) scr[i][j].style.filter = br;
      }
    };
    var measure = function () {
      C.vpW = vp.clientWidth;
      C.centers = slides.map(function (s) { return s.offsetLeft + s.offsetWidth / 2; });
      C.pitch = n > 1 ? Math.max(1, C.centers[1] - C.centers[0]) : 400;
      C.target = offsetFor(C.idx);
      if (!C.anim && !C.drag) C.x = C.target;
      render();
    };
    var setIdx = function (i) {
      if (S.index === i) return;
      setIndex(i);
      var g = w.gsap;
      if (g) g.fromTo('.dots', { y: 6, opacity: 0.4 }, { y: 0, opacity: 1, duration: 0.45, ease: 'power3.out', overwrite: true });
    };
    var step = function (now) {
      var dt = Math.min(0.032, Math.max(0, (now - C.last) / 1000));
      C.last = now;
      var om = 2 * Math.PI / 0.42;
      var sub = 4, h = dt / sub;
      for (var k = 0; k < sub; k++) {
        var acc = -om * om * (C.x - C.target) - 2 * om * C.v;
        C.v += acc * h;
        C.x += C.v * h;
      }
      if (Math.abs(C.x - C.target) < 0.4 && Math.abs(C.v) < 8) {
        C.x = C.target; C.v = 0; render(); C.anim = false; C.raf = 0;
        return;
      }
      render();
      C.raf = requestAnimationFrame(step);
    };
    var stopSpring = function () {
      if (C.raf) cancelAnimationFrame(C.raf);
      C.raf = 0; C.anim = false;
    };
    var animateTo = function (i, v0) {
      i = Math.max(0, Math.min(n - 1, i));
      C.idx = i;
      C.target = offsetFor(i);
      setIdx(i);
      C.v = v0 || 0;
      if (!C.anim) { C.anim = true; C.last = performance.now(); C.raf = requestAnimationFrame(step); }
    };
    var auto = 0;
    // Called only for the visitor's own actions: autoplay stops for good, and from then on
    // caption changes are announced (they stay silent while the carousel rotates by itself).
    var stopAuto = function () {
      C.touched = true;
      if (auto) { clearInterval(auto); auto = 0; }
      if (capsEl) capsEl.setAttribute('aria-live', 'polite');
    };
    var rubber = function (raw) {
      var max = 0, min = offsetFor(n - 1), d = C.vpW || 1;
      var rb = function (o) { return (o * d * 0.55) / (d + 0.55 * o); };
      if (raw > max) return max + rb(raw - max);
      if (raw < min) return min - rb(min - raw);
      return raw;
    };
    var nearest = function (pos) {
      var best = 0, bd = Infinity;
      for (var i = 0; i < n; i++) { var d = Math.abs(offsetFor(i) - pos); if (d < bd) { bd = d; best = i; } }
      return best;
    };
    var wrapI = function (i) { return (i + n) % n; };

    var onDown = function (e) {
      if (e.button && e.button !== 0) return;
      stopAuto();
      stopSpring();
      C.down = true; C.drag = false;
      C.sx = e.clientX; C.sy = e.clientY; C.x0 = C.x; C.pid = e.pointerId;
      C.hist = [{ x: e.clientX, t: e.timeStamp }];
    };
    var onUp = function (e) {
      if (!C.down) return;
      C.down = false;
      if (!C.drag) { animateTo(C.idx, 0); return; }
      C.drag = false;
      vp.classList.remove('is-drag');
      try { vp.releasePointerCapture(C.pid); } catch (er) {}
      var now = (e && e.timeStamp) || performance.now(), first = C.hist[0];
      for (var i = C.hist.length - 1; i >= 0; i--) { if (now - C.hist[i].t > 90) { first = C.hist[i]; break; } }
      var lastS = C.hist[C.hist.length - 1];
      var dtS = Math.max(0.016, (lastS.t - first.t) / 1000);
      var v = (lastS.x - first.x) / dtS;
      if (now - lastS.t > 120) v = 0;
      // Project where the flick would come to rest, then snap to the nearest slide.
      var projected = C.x + (v / 1000) * 0.998 / (1 - 0.998);
      animateTo(nearest(projected), v);
    };
    var onMove = function (e) {
      if (!C.down) return;
      if (C.drag && e.buttons === 0) { onUp(e); return; }
      var dx = e.clientX - C.sx, dy = e.clientY - C.sy;
      if (!C.drag) {
        if (Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy)) {
          C.drag = true;
          try { vp.setPointerCapture(C.pid); } catch (er) {}
          vp.classList.add('is-drag');
          C.sx = e.clientX; C.x0 = C.x;
        } else if (Math.abs(dy) > 10) {
          C.down = false;
          animateTo(C.idx, 0);
        }
        return;
      }
      C.x = rubber(C.x0 + (e.clientX - C.sx));
      C.hist.push({ x: e.clientX, t: e.timeStamp });
      if (C.hist.length > 8) C.hist.shift();
      render();
    };
    var onKey = function (e) {
      if (e.key === 'ArrowRight') { e.preventDefault(); stopAuto(); animateTo(wrapI(C.idx + 1), 0); }
      else if (e.key === 'ArrowLeft') { e.preventDefault(); stopAuto(); animateTo(wrapI(C.idx - 1), 0); }
    };
    vp.addEventListener('pointerdown', onDown);
    vp.addEventListener('pointermove', onMove);
    vp.addEventListener('pointerup', onUp);
    vp.addEventListener('pointercancel', onUp);
    // A touch pointer starts captured by the element under the finger; moving the capture to the
    // viewport fires lostpointercapture on that inner element, which bubbles here. Only the
    // viewport's own loss of this pointer ends the drag.
    vp.addEventListener('lostpointercapture', function (e) { if (e.target === vp && e.pointerId === C.pid) onUp(e); });
    // Safety net for a release that never reaches the viewport.
    var onWinUp = function (e) { if (C.down && e.pointerId === C.pid) onUp(e); };
    w.addEventListener('pointerup', onWinUp);
    w.addEventListener('pointercancel', onWinUp);
    w.addEventListener('blur', onUp);
    html.addEventListener('mouseleave', function (e) { if (C.drag && e.buttons === 0) onUp({ timeStamp: performance.now() }); });
    vp.addEventListener('keydown', onKey);

    // Autoplay holds while the pointer rests on the carousel or focus is inside it.
    var carBox = vp.parentNode;
    carBox.addEventListener('pointerenter', function (e) { if (e.pointerType === 'mouse') C.hover = true; });
    carBox.addEventListener('pointerleave', function (e) { if (e.pointerType === 'mouse') C.hover = false; });
    [carBox, dotsEl].forEach(function (el) {
      if (!el) return;
      el.addEventListener('focusin', function () { C.focus = true; });
      el.addEventListener('focusout', function (e) {
        var to = e.relatedTarget;
        C.focus = !!(to && (carBox.contains(to) || (dotsEl && dotsEl.contains(to))));
      });
    });

    // Load every slide's image before the carousel scrolls into view, so no slide is blank mid-spring.
    var slideImgs = Array.prototype.slice.call(track.querySelectorAll('img[loading="lazy"]'));
    var eager = function () { slideImgs.forEach(function (im) { im.loading = 'eager'; }); };
    if (w.IntersectionObserver) {
      var near = new IntersectionObserver(function (entries) {
        if (entries[0].isIntersecting) { eager(); near.disconnect(); }
      }, { rootMargin: '0px 0px 800px 0px' });
      near.observe(vp);
    } else {
      eager();
    }

    measure();
    if (w.ResizeObserver) {
      new ResizeObserver(function () { measure(); }).observe(vp);
    } else {
      w.addEventListener('resize', measure);
    }

    car = {
      go: function (i) { stopAuto(); animateTo(i, 0); },
      step: function (d) { stopAuto(); animateTo(wrapI(C.idx + d), 0); }
    };

    if (w.IntersectionObserver) {
      new IntersectionObserver(function (entries) { C.visible = entries[0].isIntersecting; }).observe(vp);
    }
    auto = setInterval(function () {
      if (C.touched || !C.visible || doc.hidden || C.down || C.hover || C.focus) return;
      animateTo((C.idx + 1) % n, 0);
    }, 5000);
  };

  var carStep = function (d) {
    if (car) { car.step(d); return; }
    var n = 5, i = (S.index || 0) + d;
    setIndex((i + n) % n);
  };
  var carGo = function (i) {
    if (car) { car.go(i); return; }
    setIndex(i);
  };
  var prevBtn = doc.querySelector('.arrow-prev');
  var nextBtn = doc.querySelector('.arrow-next');
  if (prevBtn) prevBtn.addEventListener('click', function () { carStep(-1); });
  if (nextBtn) nextBtn.addEventListener('click', function () { carStep(1); });
  dotEls.forEach(function (d, i) { d.addEventListener('click', function () { carGo(i); }); });

  try { initCarousel(); } catch (e) {}

  var gsap = w.gsap;
  var ST = w.ScrollTrigger;
  if (!gsap) { unhold(); return; }
  if (ST) gsap.registerPlugin(ST);

  /* ---------- entrance: copy reveal, phones settling in ---------- */
  // The top bar is never held back by boot.js, so on a slow load it is already on screen when this
  // runs. Its entrance plays only when nothing has been painted yet (or just now), so it never blinks.
  var barPainted = function () {
    try {
      var p = performance.getEntriesByName('first-contentful-paint')[0];
      return !!p && performance.now() - p.startTime > 250;
    } catch (e) { return false; }
  };
  var heroIn = function () {
    var tl = gsap.timeline({ defaults: { ease: 'expo.out' } });
    if (!barPainted()) tl.from('.bar-in > *', { y: -10, opacity: 0, duration: 0.8, stagger: 0.08, ease: 'power3.out', clearProps: 'transform,opacity' }, 0);
    tl.from('.h1 .li', { yPercent: 110, duration: 1.15, stagger: 0.1 }, 0.1)
      .from('.sub', { y: 14, opacity: 0, duration: 0.9 }, 0.42)
      .from('.hero .store', { scale: 0.96, opacity: 0, duration: 0.8, stagger: 0.07, ease: 'power3.out', clearProps: 'transform,opacity' }, 0.55)
      .from('.credit', { opacity: 0, duration: 0.8 }, 0.7)
      .from('.dev-c', { y: 80, opacity: 0, duration: 1.25 }, 0.5)
      .from('.dev-r', { x: -70, y: 50, opacity: 0, duration: 1.3 }, 0.62)
      .from('.float-live', { y: 12, scale: 0.96, opacity: 0, duration: 0.8, ease: 'expo.out' }, 1.05)
      .from(gsap.utils.shuffle(gsap.utils.toArray('.fo')), { scale: 0.6, opacity: 0, duration: 0.9, stagger: 0.05, ease: 'expo.out' }, 0.65);
  };

  var startDrift = function () {
    var r = gsap.utils.random;
    gsap.utils.toArray('.fo-d').forEach(function (d) {
      drift.push(gsap.to(d, { x: r(-14, 14), duration: r(3, 7), ease: 'sine.inOut', yoyo: true, repeat: -1 }).progress(Math.random()));
      drift.push(gsap.to(d, { y: r(-18, 18), duration: r(3.4, 6.8), ease: 'sine.inOut', yoyo: true, repeat: -1 }).progress(Math.random()));
      drift.push(gsap.to(d, { rotation: r(-6, 6), duration: r(4, 7), ease: 'sine.inOut', yoyo: true, repeat: -1 }).progress(Math.random()));
    });
  };

  var aura = function () {
    var el = doc.querySelector('.aura');
    if (!el) return;
    var tw = gsap.fromTo(el, { scale: 0.96 }, { scale: 1.04, duration: 4, ease: 'sine.inOut', yoyo: true, repeat: -1 });
    ST.create({ trigger: '.hero', start: 'top bottom', end: 'bottom top', onToggle: function (s) { if (s.isActive) tw.play(); else tw.pause(); } });
  };

  var reveals = function () {
    gsap.utils.toArray('.rv').forEach(function (el) {
      gsap.from(el, { y: 12, opacity: 0, duration: 0.8, ease: 'expo.out', scrollTrigger: { trigger: el, start: 'top 90%', once: true } });
    });
    gsap.utils.toArray('.rv-group').forEach(function (g) {
      var kids = g.querySelectorAll('.rv-item');
      if (!kids.length) return;
      gsap.from(kids, { y: 12, opacity: 0, duration: 0.8, ease: 'expo.out', stagger: 0.05, scrollTrigger: { trigger: g, start: 'top 88%', once: true } });
    });
  };

  var parallax = function () {
    var mk = function () { return { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true }; };
    gsap.to('.dev-c .par', { y: -50, ease: 'none', scrollTrigger: mk() });
    gsap.to('.dev-r .par', { y: -20, ease: 'none', scrollTrigger: mk() });
    gsap.to('.float-live .par', { y: -30, ease: 'none', scrollTrigger: mk() });
  };

  /* ---------- latency proof: pinned scrub when it fits, unpinned scrub otherwise ---------- */
  var LAT_BAR = 88;
  var latPin = doc.getElementById('lat-pin');
  // Both are read again on every refresh (resize, rotation), never frozen at load time.
  var latFits = function () { return !!latPin && latPin.offsetHeight + LAT_BAR + 16 <= w.innerHeight; };
  // Centre the pinned block in the space under the sticky bar, so tall screens hold no empty band.
  var latPinTop = function () {
    return Math.round(LAT_BAR + Math.max(0, (w.innerHeight - LAT_BAR - latPin.offsetHeight) / 2));
  };
  var latency = function (pinned) {
    var pin = latPin;
    var stage = doc.getElementById('lat-stage');
    if (!pin || !stage) return null;
    // Step states are a 0..1 custom property mixed into the theme's own text colours,
    // so the dimmed and lit states stay correct in both light and dark. Their starting state
    // (step 01 lit, 02 and 03 dimmed) comes from the lat-run class in the CSS, not from an inline
    // set: ScrollTrigger's refresh can clear inline values before the scrubbed tweens record their
    // start, which used to leave every step lit. Every step tween states both ends explicitly.
    pin.classList.add('lat-run');
    var trig = pinned
      ? { trigger: pin, start: function () { return 'top ' + latPinTop() + 'px'; }, end: '+=1200', scrub: 0.8, pin: true, anticipatePin: 1, invalidateOnRefresh: true }
      : { trigger: stage, start: 'top 75%', end: 'bottom 80%', scrub: 0.6 };
    var tl = gsap.timeline({ scrollTrigger: trig });
    tl.fromTo('#lat-edge-label', { '--fl': 0 }, { '--fl': 1, duration: 0.3, ease: 'power2.out' }, 0.1)
      .to('#lat-edge-label', { '--fl': 0, duration: 0.3, ease: 'power2.in' }, 0.7)
      .fromTo('#ls1', { '--on': 1 }, { '--on': 0, duration: 0.3, immediateRender: false }, 1)
      .fromTo('#ls2', { '--on': 0 }, { '--on': 1, duration: 0.3, immediateRender: false }, 1)
      .from('#row-web', { autoAlpha: 0, y: 8, duration: 0.4 }, 1)
      .from('#web-gap', { right: '66%', duration: 1, ease: 'power1.inOut' }, 1.2)
      .from('#web-gap-label', { autoAlpha: 0, duration: 0.4 }, 1.9)
      .fromTo('#ls2', { '--on': 1 }, { '--on': 0, duration: 0.3, immediateRender: false }, 2.5)
      .fromTo('#ls3', { '--on': 0 }, { '--on': 1, duration: 0.3, immediateRender: false }, 2.5)
      .from('#row-on', { autoAlpha: 0, y: 8, duration: 0.4 }, 2.5)
      .from(['#on-head', '#on-gap'], { left: '60%', duration: 1.4, ease: 'power3.inOut' }, 2.8)
      .fromTo('#odo-list', { y: 0, yPercent: 0 }, { y: 0, yPercent: -80, duration: 1.4, ease: 'steps(4)' }, 2.8);
    if (pinned) tl.to({}, { duration: 0.6 });
    tl.fromTo('#lat-prog', { scaleX: 0 }, { scaleX: 1, duration: tl.duration(), ease: 'none' }, 0);
    return tl;
  };

  /* ---------- LIVE readout: rolls to the next value ---------- */
  var rollCounter = function (next) {
    if (S.lat === next) return;
    if (!lvN) { setLat(next); return; }
    gsap.to(lvN, {
      yPercent: -40, opacity: 0, duration: 0.08, ease: 'power2.in', overwrite: true,
      onComplete: function () {
        setLat(next);
        requestAnimationFrame(function () {
          requestAnimationFrame(function () {
            gsap.fromTo(lvN, { yPercent: 40, opacity: 0 }, { yPercent: 0, opacity: 1, duration: 0.08, ease: 'power2.out' });
          });
        });
      }
    });
  };

  /* ---------- gift pop, every ~8 s; the LIVE readout ticks with it ---------- */
  var giftPop = function () {
    var body = giftBody;
    if (!body || !body.offsetParent) return;
    var sub = doc.getElementById('chip-sub');
    var sparks = gsap.utils.toArray('#gift-body .bs');
    var size = body.clientWidth || 120;
    var tl = gsap.timeline();
    tl.to(body, { scaleX: 1.12, scaleY: 0.86, transformOrigin: '50% 100%', duration: 0.18, ease: 'power2.in' })
      .add(function () {
        setGiftOpen(true);
        sparks.forEach(function (el, i) {
          var ang = (i / sparks.length) * Math.PI * 2 + gsap.utils.random(-0.3, 0.3);
          var dist = size * gsap.utils.random(0.55, 0.9);
          gsap.fromTo(el, { x: 0, y: 0, scale: 0, rotation: 0, opacity: 1 },
            { x: Math.cos(ang) * dist, y: Math.sin(ang) * dist - size * 0.18, scale: gsap.utils.random(0.6, 1.05), rotation: gsap.utils.random(-120, 120), duration: 0.7, ease: 'power3.out' });
          gsap.to(el, { scale: 0, opacity: 0, duration: 0.35, delay: 0.55, ease: 'power2.in' });
        });
        if (sub) gsap.fromTo(sub, { scale: 1 }, { scale: 1.12, duration: 0.14, ease: 'power2.out', yoyo: true, repeat: 1 });
        rollCounter('1.9');
        if (latBack) latBack.kill();
        latBack = gsap.delayedCall(1.6, function () { rollCounter('1.8'); });
      })
      .to(body, { scaleX: 0.94, scaleY: 1.1, duration: 0.14, ease: 'power2.out' })
      .to(body, { scaleX: 1, scaleY: 1, duration: 0.6, ease: 'expo.out' })
      .to(body, { y: -6, duration: 0.18, ease: 'power2.out' }, '+=2')
      .add(function () { setGiftOpen(false); })
      .to(body, { y: 0, duration: 0.5, ease: 'expo.out' });
  };
  var giftLoop = function () {
    if (S.heroOn && !doc.hidden) giftPop();
    setTimeout(giftLoop, 8000);
  };

  /* ---------- rocket streak, every ~12 s, kept in the band above the headline ---------- */
  var rocketStreak = function () {
    var hero = doc.getElementById('hero');
    var rocket = doc.querySelector('.rocket');
    var trail = Array.prototype.slice.call(doc.querySelectorAll('.trail'));
    if (!hero || !rocket) return;
    var W = hero.clientWidth, H = hero.clientHeight;
    var R = rocket.offsetWidth / 2;
    var copy = doc.querySelector('.hero-copy');
    var band = copy ? copy.offsetTop : 60;
    var p0 = { x: -90, y: Math.min(H * 0.16, band * 0.85) }, p1 = { x: W * 0.5, y: band * 0.08 }, p2 = { x: W + 90, y: Math.min(H * 0.06, band * 0.35) };
    var hist = [];
    var o = { t: 0 };
    var park = 'translate3d(-300px,-300px,0)';
    gsap.to(o, {
      t: 1, duration: 2.4, ease: 'power1.inOut',
      onUpdate: function () {
        var t = o.t, u = 1 - t;
        var x = u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x;
        var y = u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y;
        var dx = 2 * u * (p1.x - p0.x) + 2 * t * (p2.x - p1.x);
        var dy = 2 * u * (p1.y - p0.y) + 2 * t * (p2.y - p1.y);
        var ang = Math.atan2(dy, dx) * 180 / Math.PI + 45;
        rocket.style.transform = 'translate3d(' + (x - R) + 'px,' + (y - R) + 'px,0) rotate(' + ang.toFixed(1) + 'deg)';
        hist.unshift({ x: x, y: y });
        if (hist.length > 48) hist.pop();
        for (var k = 0; k < trail.length; k++) {
          var h = hist[Math.min(hist.length - 1, (k + 1) * 2)];
          if (!h) continue;
          var f = 1 - k / trail.length;
          trail[k].style.transform = 'translate3d(' + (h.x - 3.5) + 'px,' + (h.y - 3.5) + 'px,0) scale(' + (0.35 + f * 0.65).toFixed(2) + ')';
          trail[k].style.opacity = (f * 0.6).toFixed(2);
        }
      },
      onComplete: function () {
        rocket.style.transform = park;
        trail.forEach(function (d) { d.style.transform = park; d.style.opacity = ''; });
      }
    });
  };
  var rocketLoop = function () {
    if (S.heroOn && !doc.hidden) rocketStreak();
    setTimeout(rocketLoop, 12000);
  };

  /* ---------- pointer parallax, scatter and scroll depth for the floating objects ---------- */
  var initField = function () {
    var hero = doc.getElementById('hero');
    if (!hero) return;
    var fine = !!(w.matchMedia && w.matchMedia('(hover: hover) and (pointer: fine)').matches);
    var objs = Array.prototype.slice.call(hero.querySelectorAll('.fo')).map(function (el) {
      return { el: el, p: el.querySelector('.fo-p'), depth: parseFloat(el.getAttribute('data-depth')) || 0.5,
        gift: el.classList.contains('fo-gift'), cx: 0, cy: 0, x: 0, y: 0, vx: 0, vy: 0, r: 0, vr: 0 };
    });
    var P = { x: 0, y: 0, nx: 0, ny: 0, on: false };
    var measure = function () {
      objs.forEach(function (o) {
        o.cx = o.el.offsetLeft + o.el.offsetWidth / 2;
        o.cy = o.el.offsetTop + o.el.offsetHeight / 2;
      });
    };
    measure();
    // The loop sleeps once every object has settled; pointer, scroll and resize wake it.
    var wake = function () { if (fieldStart) fieldStart(); };
    var onMove = function (e) {
      if (!fine) return;
      var r = hero.getBoundingClientRect();
      P.x = e.clientX - r.left; P.y = e.clientY - r.top;
      P.nx = (P.x / r.width) * 2 - 1; P.ny = (P.y / r.height) * 2 - 1;
      P.on = true;
      wake();
    };
    var onLeave = function () { P.on = false; P.nx = 0; P.ny = 0; wake(); };
    hero.addEventListener('pointermove', onMove, { passive: true });
    hero.addEventListener('pointerleave', onLeave);
    w.addEventListener('blur', onLeave);
    w.addEventListener('resize', function () { measure(); wake(); });
    w.addEventListener('scroll', wake, { passive: true });

    var OM = 2 * Math.PI / 0.55;
    var RAD = 150;
    var last = performance.now();
    var run = false;
    var raf = 0;
    var loop = function (now) {
      if (!run) return;
      var dt = Math.min(0.033, Math.max(0, (now - last) / 1000));
      last = now;
      var r = hero.getBoundingClientRect();
      var scrolled = Math.max(0, -r.top);
      var busy = false;
      for (var i = 0; i < objs.length; i++) {
        var o = objs[i];
        var tx = P.nx * o.depth * 22;
        var ty = P.ny * o.depth * 16 - scrolled * o.depth * 0.18;
        var tr = 0;
        if (P.on) {
          var dx = o.cx - P.x, dy = o.cy - P.y;
          var d = Math.sqrt(dx * dx + dy * dy) || 1;
          if (d < RAD) {
            var f = 1 - d / RAD;
            var push = f * f * 48 * (0.6 + o.depth);
            tx += (dx / d) * push;
            ty += (dy / d) * push;
            if (o.gift) tr = -(dx / d) * 2 * f;
          }
        }
        // Critically damped, except the gift, which arrives with a little momentum.
        var z = o.gift ? 0.62 : 1;
        var steps = 2, h = dt / steps;
        for (var s = 0; s < steps; s++) {
          var ax = -OM * OM * (o.x - tx) - 2 * z * OM * o.vx;
          var ay = -OM * OM * (o.y - ty) - 2 * z * OM * o.vy;
          var ar = -OM * OM * (o.r - tr) - 2 * z * OM * o.vr;
          o.vx += ax * h; o.vy += ay * h; o.vr += ar * h;
          o.x += o.vx * h; o.y += o.vy * h; o.r += o.vr * h;
        }
        if (o.p) o.p.style.transform = 'translate3d(' + o.x.toFixed(2) + 'px,' + o.y.toFixed(2) + 'px,0)' + (o.gift ? ' rotate(' + o.r.toFixed(2) + 'deg)' : '');
        if (Math.abs(o.x - tx) > 0.02 || Math.abs(o.y - ty) > 0.02 || Math.abs(o.r - tr) > 0.01 ||
            Math.abs(o.vx) > 0.05 || Math.abs(o.vy) > 0.05 || Math.abs(o.vr) > 0.05) busy = true;
      }
      if (!busy) { run = false; raf = 0; return; }
      raf = requestAnimationFrame(loop);
    };
    fieldStart = function () {
      if (run || !S.heroOn || doc.hidden) return;
      run = true;
      last = performance.now();
      raf = requestAnimationFrame(loop);
    };
    fieldStop = function () {
      run = false;
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    };
    fieldStart();
  };

  /* ---------- pause the hero's loops when it is off-screen or the tab is hidden ---------- */
  var watchHero = function () {
    var hero = doc.getElementById('hero');
    var apply = function () {
      var on = S.heroOn && !doc.hidden;
      drift.forEach(function (t) { if (on) t.play(); else t.pause(); });
      if (on) { if (fieldStart) fieldStart(); }
      else if (fieldStop) fieldStop();
    };
    if (hero && w.IntersectionObserver) {
      new IntersectionObserver(function (entries) { S.heroOn = entries[0].isIntersecting; apply(); }).observe(hero);
    }
    doc.addEventListener('visibilitychange', apply);
  };

  /* ---------- start ---------- */
  // Lenis only smooths wheel scrolling; on touch-first devices it would add per-frame work for nothing.
  if (w.Lenis && ST && finePointer) {
    try {
      var lenis = new w.Lenis({ lerp: 0.1, smoothWheel: true });
      lenis.on('scroll', ST.update);
      // Lenis is driven by GSAP's ticker only while it is easing a scroll, so the ticker can sleep
      // when the page is idle. Its clock is reset on wake so the first frame never jumps.
      var lenisOn = false;
      var lenisTick = function () {
        lenis.raf(performance.now());
        if (!lenis.isScrolling) { gsap.ticker.remove(lenisTick); lenisOn = false; }
      };
      var lenisWake = function () {
        if (lenisOn) return;
        lenisOn = true;
        lenis.raf(performance.now());
        gsap.ticker.add(lenisTick);
      };
      lenis.on('virtual-scroll', lenisWake);
      w.addEventListener('wheel', lenisWake, { passive: true });
      gsap.ticker.lagSmoothing(0);
    } catch (e) {}
  }
  if (ST) ST.config({ ignoreMobileResize: true });

  unhold();
  if (!revealedEarly) heroIn();
  startDrift();
  if (ST) { if (!revealedEarly) reveals(); aura(); }
  // Plain timers rather than GSAP delayed calls, so GSAP's ticker can sleep once the hero is off-screen.
  setTimeout(giftLoop, 2400);
  setTimeout(rocketLoop, 5000);
  initField();
  watchHero();

  if (ST) {
    var mm = gsap.matchMedia();
    mm.add({
      roomy: '(min-width: 768px) and (min-height: 760px)',
      compact: '(max-width: 767px), (max-height: 759px)'
    }, function (c) {
      var roomy = !!c.conditions.roomy;
      var lat = null;
      var mode = null;
      // Pinned only while the block fits under the bar; re-decided after every resize or rotation.
      var build = function () {
        var pinned = roomy && latFits();
        if (lat && mode === pinned) return false;
        if (lat) lat.revert();
        mode = pinned;
        lat = latency(pinned);
        return true;
      };
      build();
      if (roomy) parallax();
      var rt = 0;
      var onResize = function () {
        clearTimeout(rt);
        rt = setTimeout(function () {
          var changed = false;
          c.add(function () { changed = build(); });
          if (changed) ST.refresh();
        }, 250);
      };
      w.addEventListener('resize', onResize);
      return function () { clearTimeout(rt); w.removeEventListener('resize', onResize); };
    });
    var refresh = function () { if (w.ScrollTrigger) w.ScrollTrigger.refresh(); };
    if (doc.fonts && doc.fonts.ready) doc.fonts.ready.then(refresh);
    w.addEventListener('load', refresh);
  }
})();
