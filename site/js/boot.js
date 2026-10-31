/* Runs before first paint: marks the page as scripted and holds the hero until its entrance starts. */
(function () {
  var d = document.documentElement;
  d.classList.add('js', 'pre');
  var show = function () { d.classList.remove('pre'); };
  // Failsafe for a slow network: never keep the hero hidden for more than 3 s.
  setTimeout(show, 3000);
  window.addEventListener('load', function () {
    show();
    // Every deferred script has run by now. Without site.js, fall back to the no-script layout
    // (native-scroll carousel, all captions, no dead controls).
    if (!d.classList.contains('js-ready')) d.classList.remove('js');
  });
})();
