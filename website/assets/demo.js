/* Demo films for solid.express (homepage few + features page full set).
 *
 * Data: assets/demo-catalog.json, emitted by tools/website_demos.py.
 *   featured[] = every curated film {id, feature, title, caption, group, order, home, hero}
 *   groups[]   = features-page sections, in order
 *
 * HARD RULE: a card is only playable when its id is on the live demo-movies
 * Release (or the committed published-demos.json fallback). A missing WebM
 * never becomes a play button.
 *
 * Loading: posters only (<img loading=lazy>). A WebM is fetched on hover
 * (muted preview) or click (lightbox), never up front.
 */
(function (global) {
  var CATALOG_URL = "assets/demo-catalog.json";
  var PUBLISHED_URL = "assets/published-demos.json";
  var POSTER_BASE = "assets/screenshots/";
  var DEFAULT_BASE = "https://github.com/solidexpress/solidexpress/releases/download/demo-movies/";
  var DEFAULT_API = "https://api.github.com/repos/solidexpress/solidexpress/releases/tags/demo-movies";
  var CAN_HOVER = global.matchMedia && global.matchMedia("(hover: hover)").matches;

  function fetchJson(url) {
    return fetch(url, { cache: "no-cache" }).then(function (r) {
      if (!r.ok) throw new Error(url + " HTTP " + r.status);
      return r.json();
    });
  }

  function idSet(ids) {
    var out = {};
    ids.forEach(function (id) { out[id] = true; });
    return out;
  }

  function releaseIds(release) {
    return ((release && release.assets) || [])
      .map(function (a) { return a.name || ""; })
      .filter(function (n) { return /\.webm$/i.test(n); })
      .map(function (n) { return n.replace(/\.webm$/i, ""); });
  }

  /* Ids with a WebM: live Release listing, else the committed fallback. */
  function loadAvailable(catalog) {
    var api = (catalog.demo_release || {}).api || DEFAULT_API;
    return fetchJson(PUBLISHED_URL).catch(function () { return []; }).then(function (published) {
      return fetchJson(api)
        .then(function (release) {
          var live = releaseIds(release);
          return idSet(live.length ? live : published);
        })
        .catch(function () { return idSet(published); });
    });
  }

  function movieUrl(catalog, id) {
    return ((catalog.demo_release || {}).base || DEFAULT_BASE) + id + ".webm";
  }

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text) node.textContent = text;
    return node;
  }

  function bindLightbox() {
    var box = document.getElementById("demo-lightbox");
    var video = document.getElementById("demo-lightbox-video");
    var title = document.getElementById("demo-lightbox-title");
    var closeBtn = document.getElementById("demo-lightbox-close");
    var openLink = document.getElementById("demo-lightbox-open");
    var lastFocus = null;
    if (!box || !video) return { open: function () {} };

    function close() {
      video.pause();
      video.removeAttribute("src");
      video.load();
      box.classList.remove("open");
      box.hidden = true;
      document.body.style.overflow = "";
      if (lastFocus) lastFocus.focus();
    }
    function open(trigger, film, src) {
      lastFocus = trigger;
      title.textContent = film.title;
      if (openLink) openLink.href = src;
      video.src = src;
      box.hidden = false;
      box.classList.add("open");
      document.body.style.overflow = "hidden";
      video.play().catch(function () {});
      if (closeBtn) closeBtn.focus();
    }
    if (closeBtn) closeBtn.addEventListener("click", close);
    box.addEventListener("click", function (e) { if (e.target === box) close(); });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && box.classList.contains("open")) close();
    });
    return { open: open };
  }

  /* Muted hover preview: the <video> is created on first hover, removed on leave. */
  function attachPreview(media, src) {
    if (!CAN_HOVER) return;
    var video = null;
    media.addEventListener("mouseenter", function () {
      video = document.createElement("video");
      video.muted = true;
      video.loop = true;
      video.playsInline = true;
      video.preload = "auto";
      video.src = src;
      video.addEventListener("playing", function () { media.classList.add("previewing"); });
      media.appendChild(video);
      video.play().catch(function () {});
    });
    media.addEventListener("mouseleave", function () {
      media.classList.remove("previewing");
      if (!video) return;
      video.pause();
      video.removeAttribute("src");
      video.load();
      video.remove();
      video = null;
    });
  }

  function filmCard(film, ctx, opts) {
    var playable = !!ctx.available[film.id];
    var card = el("article", "film" + (opts.hero ? " hero" : ""));
    var media = el("button", "media");
    media.type = "button";
    media.setAttribute("aria-label", (playable ? "Play demo: " : "") + film.title);

    var img = el("img");
    img.loading = opts.hero ? "eager" : "lazy";
    img.decoding = "async";
    img.alt = "";
    img.width = 1600;
    img.height = 900;
    img.src = POSTER_BASE + film.id + ".png";
    media.appendChild(img);

    if (playable) {
      var src = movieUrl(ctx.catalog, film.id);
      media.setAttribute("data-demo", film.id);
      media.appendChild(el("span", "play"));
      media.addEventListener("click", function () { ctx.lightbox.open(media, film, src); });
      attachPreview(media, src);
    }
    card.appendChild(media);

    var body = el("div", "body");
    if (opts.tag) body.appendChild(el("span", "tag", film.feature));
    body.appendChild(el("h3", "", film.title));
    body.appendChild(el("p", "", film.caption));
    card.appendChild(body);
    return card;
  }

  function seeMoreCard(total, href) {
    var a = el("a", "film see-more");
    a.href = href;
    a.appendChild(el("strong", "", "See more"));
    a.appendChild(el("span", "", "All " + total + " feature films, from sketching to assemblies."));
    a.appendChild(el("span", "arrow", "Browse the features \u2192"));
    return a;
  }

  function byOrder(a, b) {
    return (b.hero ? 1 : 0) - (a.hero ? 1 : 0) || a.order - b.order;
  }

  /* Load catalog + availability once, then hand a context to the renderer. */
  function withFilms(target, render) {
    if (!target) return;
    fetchJson(CATALOG_URL)
      .then(function (catalog) {
        return loadAvailable(catalog).then(function (available) {
          render({
            catalog: catalog,
            available: available,
            lightbox: bindLightbox(),
            films: (catalog.featured || []).slice().sort(byOrder)
          });
        });
      })
      .catch(function () {
        target.innerHTML = "<p class='lead'>Could not load the demo films.</p>";
      });
  }

  /* Homepage: the `home` tier (hero first), then a See more card. */
  function hydrateHome(gridId, moreHref) {
    var grid = document.getElementById(gridId);
    withFilms(grid, function (ctx) {
      grid.innerHTML = "";
      ctx.films.filter(function (f) { return f.home; }).forEach(function (film) {
        grid.appendChild(filmCard(film, ctx, { hero: film.hero, tag: true }));
      });
      grid.appendChild(seeMoreCard(ctx.films.length, moreHref || "features.html"));
    });
  }

  /* Features page: every film, one section per catalog group, filterable. */
  function hydrateFeatures(rootId, searchId, countId) {
    var root = document.getElementById(rootId);
    withFilms(root, function (ctx) {
      var count = countId && document.getElementById(countId);
      if (count) count.textContent = String(ctx.films.length);
      function render(term) {
        root.innerHTML = "";
        (ctx.catalog.groups || []).forEach(function (group) {
          var films = ctx.films.filter(function (f) {
            var hay = (f.title + " " + f.feature + " " + f.caption + " " + f.id).toLowerCase();
            return f.group === group && (!term || hay.indexOf(term) !== -1);
          });
          if (!films.length) return;
          var section = el("section", "film-group");
          var h2 = el("h2", "", group);
          h2.appendChild(el("small", "", films.length + (films.length === 1 ? " film" : " films")));
          section.appendChild(h2);
          var grid = el("div", "film-grid");
          films.forEach(function (film) { grid.appendChild(filmCard(film, ctx, { tag: true })); });
          section.appendChild(grid);
          root.appendChild(section);
        });
        if (!root.children.length) root.innerHTML = "<p class='lead'>No films match that filter.</p>";
      }
      render("");
      var q = searchId && document.getElementById(searchId);
      if (q) q.addEventListener("input", function () { render(q.value.trim().toLowerCase()); });
    });
  }

  global.SxDemos = { hydrateHome: hydrateHome, hydrateFeatures: hydrateFeatures };
})(window);
