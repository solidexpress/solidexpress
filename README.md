# spanner demo artifacts

Not for merge. Upload to Release `demo-movies` on `solidexpress/solidexpress`:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber spanner.webm spanner.vtt
SX_MOVIES_OUT=. SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies spanner
```

Poster: `website/assets/screenshots/spanner.png` (already on the film branch). Do not add a `website` object or grow the curated 12.
