/* Runs before first paint: marks the page as scripted and holds the hero until its entrance starts. */
(function () {
  var d = document.documentElement;
  d.classList.add('js', 'pre');
  // Failsafe: if the page script never runs, show everything once the page has loaded.
  var show = function () { d.classList.remove('pre'); };
  window.addEventListener('load', show);
  setTimeout(show, 8000);
})();
