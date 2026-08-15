/* Shared demo lightbox + catalog hydrate for solid.express.
 * HARD RULE: never render a playable card unless that id is in the live
 * demo-movies Release (or the committed published-demos.json fallback).
 * A missing WebM must not appear as a play button.
 */
(function (global) {
  var CATALOG_URL = "assets/demo-catalog.json";
  var PUBLISHED_URL = "assets/published-demos.json";
  var MANIFEST_URL = "assets/ui_movie_manifest.json";
  var POSTER_BASE = "assets/screenshots/";
  var DEFAULT_BASE = "https://github.com/solidexpress/solidexpress.github.io/releases/download/demo-movies/";
  var DEFAULT_API = "https://api.github.com/repos/solidexpress/solidexpress.github.io/releases/tags/demo-movies";

  function fetchJson(url) {
    return fetch(url, { cache: "no-cache" }).then(function (r) {
      if (!r.ok) throw new Error(url + " HTTP " + r.status);
      return r.json();
    });
  }

  function idsFromRelease(release) {
    var out = {};
    var assets = (release && release.assets) || [];
    for (var i = 0; i < assets.length; i++) {
      var name = assets[i].name || "";
      if (/\.webm$/i.test(name) && !/\.sha256$/i.test(name)) {
        out[name.replace(/\.webm$/i, "")] = true;
      }
    }
    return out;
  }

  function idsFromList(list) {
    var out = {};
    (list || []).forEach(function (id) { out[id] = true; });
    return out;
  }

  function loadAvailable(catalog) {
    var demo = (catalog && catalog.demo_release) || {};
    var api = demo.api || DEFAULT_API;
    return fetchJson(PUBLISHED_URL)
      .catch(function () { return []; })
      .then(function (published) {
        var fallback = idsFromList(published);
        return fetchJson(api)
          .then(function (release) {
            var live = idsFromRelease(release);
            return Object.keys(live).length ? live : fallback;
          })
          .catch(function () { return fallback; });
      });
  }

  function movieUrl(catalog, id) {
    var demo = (catalog && catalog.demo_release) || {};
    return (demo.base || DEFAULT_BASE) + id + ".webm";
  }

  function bindLightbox(catalog) {
    var lightbox = document.getElementById("demo-lightbox");
    var video = document.getElementById("demo-lightbox-video");
    var titleEl = document.getElementById("demo-lightbox-title");
    var closeBtn = document.getElementById("demo-lightbox-close");
    var openLink = document.getElementById("demo-lightbox-open");
    var lastFocus = null;
    if (!lightbox || !video) return { open: function () {} };

    function closeDemo() {
      video.pause();
      video.removeAttribute("src");
      video.load();
      lightbox.classList.remove("open");
      lightbox.hidden = true;
      document.body.style.overflow = "";
      if (lastFocus && lastFocus.focus) lastFocus.focus();
    }

    function openDemo(btn) {
      var id = btn.getAttribute("data-demo");
      if (!id) return;
      var src = movieUrl(catalog, id);
      lastFocus = btn;
      titleEl.textContent = (btn.getAttribute("aria-label") || "Demo").replace(/^Play demo:\s*/i, "");
      if (openLink) openLink.href = src;
      video.src = src;
      lightbox.hidden = false;
      lightbox.classList.add("open");
      document.body.style.overflow = "hidden";
      video.play().catch(function () {});
      if (closeBtn) closeBtn.focus();
    }

    if (closeBtn) closeBtn.addEventListener("click", closeDemo);
    lightbox.addEventListener("click", function (e) {
      if (e.target === lightbox) closeDemo();
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && lightbox.classList.contains("open")) closeDemo();
    });
    return { open: openDemo };
  }

  function card(entry, lightbox) {
    var article = document.createElement("article");
    article.className = "feature-card";
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "demo-open";
    btn.setAttribute("data-demo", entry.id);
    btn.setAttribute("aria-label", "Play demo: " + (entry.title || entry.id));
    var img = document.createElement("img");
    img.loading = "lazy";
    img.alt = "";
    img.width = 1600;
    img.height = 900;
    img.src = POSTER_BASE + entry.id + ".png";
    img.onerror = function () { img.style.display = "none"; };
    var play = document.createElement("span");
    play.className = "play";
    play.setAttribute("aria-hidden", "true");
    btn.appendChild(img);
    btn.appendChild(play);
    btn.addEventListener("click", function () { lightbox.open(btn); });
    var h3 = document.createElement("h3");
    h3.textContent = entry.title || entry.id;
    var p = document.createElement("p");
    p.textContent = entry.blurb || ("Enables: " + (entry.title || entry.id));
    article.appendChild(btn);
    article.appendChild(h3);
    article.appendChild(p);
    return article;
  }

  function hydrateFeatured(gridId) {
    var grid = document.getElementById(gridId);
    if (!grid) return;
    fetchJson(CATALOG_URL)
      .then(function (catalog) {
        var lightbox = bindLightbox(catalog);
        return loadAvailable(catalog).then(function (available) {
          grid.innerHTML = "";
          (catalog.featured || []).forEach(function (entry) {
            if (!entry || !entry.id || !available[entry.id]) return;
            grid.appendChild(card(entry, lightbox));
          });
          if (!grid.children.length) {
            grid.innerHTML = "<p class='lead'>Demo movies are being refreshed. See the Features page shortly.</p>";
          }
        });
      })
      .catch(function () {
        grid.innerHTML = "<p class='lead'>Could not load the demo catalog.</p>";
      });
  }

  function hydrateLibrary(gridId, searchId) {
    var grid = document.getElementById(gridId);
    if (!grid) return;
    Promise.all([fetchJson(CATALOG_URL), fetchJson(MANIFEST_URL)])
      .then(function (pair) {
        var catalog = pair[0];
        var manifest = Array.isArray(pair[1]) ? pair[1] : [];
        var lightbox = bindLightbox(catalog);
        return loadAvailable(catalog).then(function (available) {
          var films = manifest.filter(function (e) {
            return e && e.enabled !== false && e.id && available[e.id];
          }).map(function (e) {
            return {
              id: e.id,
              title: e.title || e.id,
              blurb: "Enables: " + (e.title || e.id)
            };
          });
          function render(list) {
            grid.innerHTML = "";
            list.forEach(function (entry) { grid.appendChild(card(entry, lightbox)); });
            if (!grid.children.length) {
              grid.innerHTML = "<p class='lead'>No published demo movies match that filter.</p>";
            }
          }
          render(films);
          var q = document.getElementById(searchId);
          if (q) {
            q.addEventListener("input", function () {
              var term = q.value.trim().toLowerCase();
              render(!term ? films : films.filter(function (m) {
                return ((m.title || "") + " " + (m.id || "")).toLowerCase().indexOf(term) !== -1;
              }));
            });
          }
        });
      })
      .catch(function () {
        grid.innerHTML = "<p class='lead'>Could not load the film library.</p>";
      });
  }

  global.SxDemos = { hydrateFeatured: hydrateFeatured, hydrateLibrary: hydrateLibrary };
})(window);
