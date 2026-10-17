# flanged_pipe demo artifacts

Not for merge. Upload to Release `demo-movies` on `solidexpress/solidexpress`:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber flanged_pipe.webm flanged_pipe.vtt
SX_MOVIES_OUT=. SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature flanged_pipe
```

Poster: `website/assets/screenshots/flanged_pipe.png` (already on the cleanup branch).
