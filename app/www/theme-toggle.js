(function () {
  function applyTheme(theme) {
    document.body.setAttribute("data-theme", theme);
    try {
      sessionStorage.setItem("crm-theme", theme);
    } catch (e) {}}

  function initTheme() {
    var saved = null;
    try {
      saved = sessionStorage.getItem("crm-theme");
    } catch (e) {
      saved = null;
    }
    var theme = saved || "light";
    applyTheme(theme);
    var checkbox = document.getElementById("theme_switch");
    if (checkbox) {
      checkbox.checked = theme === "dark";}}

  document.addEventListener("DOMContentLoaded", function () {
    initTheme();
    document.body.addEventListener("change", function (e) {
      if (e.target && e.target.id === "theme_switch") {
        applyTheme(e.target.checked ? "dark" : "light");
      }});});

  if (window.Shiny) {
    Shiny.addCustomMessageHandler("crm-theme-sync", function () {
      var checkbox = document.getElementById("theme_switch");
      var current = document.body.getAttribute("data-theme") || "light";
      if (checkbox) checkbox.checked = current === "dark";});}})();