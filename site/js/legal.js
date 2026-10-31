/* Legal pages: theme toggle (dark by default, as on the home page), the current entry in the contents
   list and the floating shortcut back to the contents. Everything works without this file; without it
   the toggle stays hidden and the shortcut is always shown. */
(function () {
  'use strict';
  var doc = document;
  var w = window;
  doc.documentElement.classList.add('js');

  var init = function () {
    var root = doc.querySelector('.page');
    var tgl = doc.querySelector('.tgl');
    var themeMetas = Array.prototype.slice.call(doc.querySelectorAll('meta[name="theme-color"]'));
    var schemeMeta = doc.querySelector('meta[name="color-scheme"]');
    var light = false;
    var themeT = 0;
    if (root && tgl) {
      tgl.addEventListener('click', function () {
        light = !light;
        root.classList.add('theming');
        root.classList.toggle('theme-light', light);
        tgl.setAttribute('aria-pressed', light ? 'true' : 'false');
        var bg = light ? '#F8F8F8' : '#0A0A0A';
        doc.body.style.transition = 'background-color .3s ease';
        doc.body.style.backgroundColor = bg;
        themeMetas.forEach(function (m) { m.setAttribute('content', bg); });
        if (schemeMeta) schemeMeta.setAttribute('content', light ? 'light' : 'dark');
        if (themeT) clearTimeout(themeT);
        themeT = setTimeout(function () { root.classList.remove('theming'); }, 380);
      });
    }

    var links = Array.prototype.slice.call(doc.querySelectorAll('.toc-d a[href^="#"]'));
    var heads = Array.prototype.slice.call(doc.querySelectorAll('.policy h2[id]'));
    var tocM = doc.getElementById('contents');
    var fab = doc.querySelector('.toc-fab');
    var idx = {};
    heads.forEach(function (h, i) { idx[h.id] = i; });

    // After a jump to a section (contents click or a changed hash), that section stays marked until
    // the reader scrolls on: the last sections are too short to ever cross the reading line.
    var forced = null;
    var forcedY = 0;
    var force = function (id) {
      if (!(id in idx)) return;
      w.requestAnimationFrame(function () {
        forced = id;
        forcedY = w.scrollY;
        update();
      });
    };

    var queued = false;
    var update = function () {
      queued = false;
      if (heads.length && links.length) {
        var current = heads[0].id;
        if (forced && Math.abs(w.scrollY - forcedY) < 8) {
          current = forced;
        } else {
          forced = null;
          for (var i = 0; i < heads.length; i++) {
            if (heads[i].getBoundingClientRect().top < w.innerHeight * 0.3) current = heads[i].id;
          }
          // At the very bottom the last section is the one on screen, even if it never reached the line.
          if (w.innerHeight + w.scrollY >= doc.documentElement.scrollHeight - 2) current = heads[heads.length - 1].id;
        }
        links.forEach(function (a) {
          if (a.getAttribute('href') === '#' + current) a.setAttribute('aria-current', 'true');
          else a.removeAttribute('aria-current');
        });
      }
      if (fab && tocM) {
        var past = tocM.getBoundingClientRect().bottom < 0;
        fab.classList.toggle('is-on', past);
      }
    };
    var onScroll = function () {
      if (!queued) { queued = true; w.requestAnimationFrame(update); }
    };
    w.addEventListener('scroll', onScroll, { passive: true });
    w.addEventListener('resize', onScroll);
    w.addEventListener('hashchange', function () { force(w.location.hash.slice(1)); });
    Array.prototype.slice.call(doc.querySelectorAll('.toc a[href^="#"]')).forEach(function (a) {
      a.addEventListener('click', function () { force(a.getAttribute('href').slice(1)); });
    });
    // The shortcut opens the contents it jumps to.
    if (fab && tocM) fab.addEventListener('click', function () { tocM.open = true; });
    if (w.location.hash) force(w.location.hash.slice(1));
    update();
  };

  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', init);
  else init();
})();
