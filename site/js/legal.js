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

    var links = Array.prototype.slice.call(doc.querySelectorAll('.toc a[href^="#"]'));
    var tocD = doc.querySelector('.toc-d');
    var tocCol = doc.querySelector('.toc-col');
    var bar = doc.querySelector('.bar');
    var tables = Array.prototype.slice.call(doc.querySelectorAll('.tbl'));
    var lastCurrent = null;
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
        fitToc(current, current !== lastCurrent);
        lastCurrent = current;
      }
      if (fab && tocM) {
        var past = tocM.getBoundingClientRect().bottom < 0;
        fab.classList.toggle('is-on', past);
      }
    };
    // The sticky list is never taller than the room between the bar and the end of its column, so at
    // the bottom of the page it shrinks instead of sliding under the bar. When it is cut, it scrolls
    // itself (never the page) to keep the current entry in view, and fades out at the cut edge.
    // The entry is brought back into view when it changes or when the list's height changes, and is
    // otherwise left alone, so the reader can still scroll the list by hand.
    var lastMax = 0;
    var fitToc = function (current, changed) {
      if (!tocD || !tocCol || tocD.offsetParent === null) return;
      var barBottom = bar ? bar.getBoundingClientRect().bottom : 0;
      var room = Math.min(w.innerHeight - barBottom - 48, tocCol.getBoundingClientRect().bottom - barBottom - 40);
      var max = Math.max(120, Math.floor(room));
      if (max !== lastMax) { tocD.style.maxHeight = max + 'px'; changed = true; lastMax = max; }
      if (changed) {
        var a = tocD.querySelector('a[href="#' + current + '"]');
        if (a) {
          // The list is sticky, so it is the links' offset parent. The margin keeps the entry out of the fade.
          var top = a.offsetTop;
          var bot = top + a.offsetHeight;
          if (top - 28 < tocD.scrollTop) tocD.scrollTop = top - 28;
          else if (bot + 28 > tocD.scrollTop + tocD.clientHeight) tocD.scrollTop = bot - tocD.clientHeight + 28;
        }
      }
      fade();
    };
    var fade = function () {
      if (!tocD) return;
      tocD.classList.toggle('is-cut-top', tocD.scrollTop > 1);
      tocD.classList.toggle('is-cut-bottom', tocD.scrollTop + tocD.clientHeight < tocD.scrollHeight - 1);
    };
    if (tocD) tocD.addEventListener('scroll', fade, { passive: true });

    // A table is a tab stop only while it has something to scroll (stacked phone tables do not).
    var tabStops = function () {
      tables.forEach(function (t) {
        if (t.scrollWidth > t.clientWidth + 1) t.setAttribute('tabindex', '0');
        else t.removeAttribute('tabindex');
      });
    };

    var onScroll = function () {
      if (!queued) { queued = true; w.requestAnimationFrame(update); }
    };
    w.addEventListener('scroll', onScroll, { passive: true });
    w.addEventListener('resize', function () { onScroll(); tabStops(); });
    w.addEventListener('hashchange', function () { force(w.location.hash.slice(1)); });
    Array.prototype.slice.call(doc.querySelectorAll('.toc a[href^="#"]')).forEach(function (a) {
      a.addEventListener('click', function () { force(a.getAttribute('href').slice(1)); });
    });
    // The shortcut opens the contents it jumps to.
    if (fab && tocM) fab.addEventListener('click', function () { tocM.open = true; });
    if (w.location.hash) force(w.location.hash.slice(1));
    tabStops();
    update();
  };

  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', init);
  else init();
})();
