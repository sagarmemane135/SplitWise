# GitHub Pages + P2P Notes

## What is implemented
- Invite links generated in web mode use the current hosted origin/path and hash route:
  - `https://<user>.github.io/SplitWise/#/join?groupId=...&token=...`
- App can parse join params from:
  - URL query (`?groupId=...&token=...`)
  - Hash route query (`#/join?groupId=...&token=...`)
- On web app startup, join link is auto-processed when params are present.

## Important limitation
GitHub Pages is static hosting only. It does **not** provide realtime signaling APIs for WebRTC offer/answer and ICE exchange.

Without a signaling path, internet-grade automatic peer connection cannot be guaranteed.

## What still works without signaling service
- Link-based group invitation and identity join logic in-app.
- Local/offline experience.
- Manual or out-of-band signaling can be built later (copy/paste SDP) but UX is poor.

## Deployment notes
- Workflow file: `.github/workflows/deploy-pages.yml`
- Current base href is set to `/SplitWise/`.
- If repository name changes, update the workflow build command accordingly.
