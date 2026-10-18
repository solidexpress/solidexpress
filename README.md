# candlestick demo artifacts

Not for merge. Upload to Release `demo-movies` on `solidexpress/solidexpress`:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber candlestick.webm candlestick.vtt
SX_MOVIES_OUT=. SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies candlestick
```

Poster: `website/assets/screenshots/candlestick.png` (already on the film branch). Do not add a `website` object or grow the curated 12.
