# Cropping meme screenshots from phone gallery/player UI

## User preference

- Remove only the gray status/player areas above and below the central meme.
- Preserve the complete white meme canvas and original width; do not stretch or tightly crop the character.
- For batches, return every image individually, numbered, and in original order. Do not ZIP unless explicitly requested.

## Validated workflow

1. Count all attached paths before processing and persist an input manifest.
2. Run `scripts/crop_screenshot_meme.py IMAGE... --outdir DIR --contact-sheet`.
3. Verify output count equals input count and no output has a uniform dark-gray first/last row.
4. Inspect the numbered contact sheet for clipped heads/limbs and leftover status/player UI.
5. Send each result with its own `MEDIA:` line in original order.

## Important detection lesson

Do **not** choose the crop from global white-pixel ratio or the longest continuous white run. Black meme strokes can touch image edges or split a white canvas into several apparent runs. In the validated 33-image batch, that approach truncated 7 images to only a face/body fragment.

The working method identifies sustained transitions between nearly-uniform medium/dark gray viewer rows and non-uniform/white canvas rows. It ignores early status-bar icon transitions by starting the search after 15% of image height. This correctly handled two screenshot layouts and all 33 images.
