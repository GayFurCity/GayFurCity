$(function () {
  const el = document.querySelector("header#top menu.secondary");
  if (!el) return;

  const minFontSize = 10;
  const step = 0.5;

  function fit () {
    el.style.fontSize = "";
    let fontSize = parseFloat(getComputedStyle(el).fontSize);

    while (el.scrollWidth > el.clientWidth && fontSize > minFontSize) {
      fontSize -= step;
      el.style.fontSize = `${fontSize}px`;
    }
  }

  fit();
  $(window).on("resize.danbooru", fit);
  // Some pages toggle secondary-link visibility/text after load (e.g. the janitor approvals
  // toggle) without a resize - childList/subtree covers content changes, deliberately excluding
  // `attributes` so fit()'s own `el.style.fontSize` writes don't trigger themselves in a loop.
  new MutationObserver(fit).observe(el, { childList: true, subtree: true, characterData: true });
});
