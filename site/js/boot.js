/* Runs before first paint: sends a French visitor from / to /fr/ (a stored choice wins), remembers the language
   the visitor picks in the switch, marks the page as scripted and holds the hero until its entrance starts. */
(function () {
  var d = document;
  var KEY = 'onset.lang';

  // The language switch stores an explicit choice: "en" stops the redirect for good, "fr" makes / open /fr/.
  d.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[data-lang]') : null;
    if (!a) return;
    try { window.localStorage.setItem(KEY, a.getAttribute('data-lang')); } catch (er) {}
  }, true);

  var redirect = function () {
    var path = location.pathname;
    if (path !== '/' && path !== '/index.html') return false;
    var stored = null;
    try { stored = window.localStorage.getItem(KEY); } catch (er) {}
    // An explicit English choice keeps the English page; an explicit French one goes to /fr/ whatever
    // the browser language.
    if (stored === 'en') return false;
    var nav = window.navigator || {};
    // Crawlers and automated browsers always get the page they asked for.
    if (nav.webdriver) return false;
    if (/bot|crawl|spider|slurp|archiver|preview|lighthouse|headless|facebookexternalhit|embedly|whatsapp|telegram|discord|slack|skype|vkshare|pinterest|google-|mediapartners|chatgpt|gptbot|perplexity|bytespider|petal/i.test(nav.userAgent || '')) return false;
    // Coming from another page of this site is a deliberate visit to the English page (this also
    // keeps the English link on /fr/ working when the browser blocks storage).
    var ref = d.referrer || '';
    if (ref && ref.indexOf(location.protocol + '//' + location.host + '/') === 0) return false;
    var first = (nav.languages && nav.languages[0]) || nav.language || '';
    if (stored !== 'fr' && !/^fr(?:[-_]|$)/i.test(first)) return false;
    // Nothing of the English page is painted while the French one loads.
    d.documentElement.style.visibility = 'hidden';
    var unhide = function () { d.documentElement.style.visibility = ''; };
    window.addEventListener('pageshow', function (e) { if (e.persisted) unhide(); });
    setTimeout(unhide, 8000);
    location.replace('/fr/' + location.search + location.hash);
    return true;
  };
  try { redirect(); } catch (er) { d.documentElement.style.visibility = ''; }

  var h = d.documentElement;
  h.classList.add('js', 'pre');
  var show = function () { h.classList.remove('pre'); };
  // Failsafe for a slow network: never keep the hero hidden for more than 3 s.
  setTimeout(show, 3000);
  window.addEventListener('load', function () {
    show();
    // Every deferred script has run by now. Without site.js, fall back to the no-script layout
    // (native-scroll carousel, all captions, no dead controls).
    if (!h.classList.contains('js-ready')) h.classList.remove('js');
  });
})();
