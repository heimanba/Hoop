# Hoop Product Capabilities Promo

Product-capability promo film for Hoop, built with HyperFrames.

## Narrative

This cut explains Hoop as an AI coach that stays attached to a single sports video:

- confusing replay moments become concrete questions
- one uploaded video becomes a stable place for AI analysis
- the user can keep asking follow-up questions against the same clip
- repeated uploads become a visible growth record

The piece is product-led, not a family-story sequel and not a launch hype trailer.

## Assets

- `assets/app-fresh-entry.png`: fresh screenshot captured from `./scripts/build-and-launch.sh` on April 25, 2026
- `assets/app-publish-video.png`: real publish-video screen capture, suitable for the upload/publish step but not currently used in the cut
- `assets/app-unified-home.png`: real home/upload flow screenshot from `.build/screenshots/hoop-promo-home.png`
- `assets/app-timeline-card.png`: single-card feed capture from `.build/screenshots/home-redesign.png`, currently used for the growth-record closing scene
- `assets/hoop-logo.png`: app icon from `Hoop/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- `bed-product.mp3`: source music bed used for adaptation
- `assets/bed-product.m4a`: 42-second adapted bed rendered from `bed-product.mp3` starting at `143s`

## Preview

```bash
cd /Users/mamba/workspace/ios-app/Hoop/promo/hoop-product-capabilities
npx hyperframes preview
```

`preview` now uses a vendored `assets/gsap.min.js` copy so the studio does not depend on loading GSAP from a CDN.

## Validation

```bash
cd /Users/mamba/workspace/ios-app/Hoop/promo/hoop-product-capabilities
npx hyperframes lint
npx hyperframes validate
```

## Render

```bash
cd /Users/mamba/workspace/ios-app/Hoop/promo/hoop-product-capabilities
npx hyperframes render index.html --output ../../.build/renders/hoop-product-capabilities.mp4
```

## Notes

- Duration is fixed at `42s`
- Audio is music-only; there is no TTS or voiceover track
- The bed is intentionally non-piano and lightly electronic so the film reads as product promo rather than family documentary
- The soundtrack is adapted locally with `ffmpeg` from `bed-product.mp3`, using the `143s` to `185s` section so the cut lands on a natural ending
- The composition uses blur-crossfade scene transitions throughout to avoid jump cuts
- Several scenes pair real app screenshots with explanatory editorial cards so the UI stays legible in 16:9
