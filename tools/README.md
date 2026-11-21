# Converting ArcFace to Core ML

`convert_arcface.py` turns InsightFace's official ArcFace weights (ONNX) into
`glance/Models/ArcFace.mlpackage`, ready for `ArcFaceEmbedder.swift` to load.
The bundled model is **w600k_r50** (ResNet-50, from the `buffalo_l` pack, ~83MB
as FP16) — build it with `--variant w600k_r50`. Run this yourself — it
downloads ~2GB of Python tooling (torch, coremltools) and ~290MB for the
`buffalo_l` pack (of which `w600k_r50.onnx` is ~174MB) from InsightFace's own hosting.

## Run it

```bash
cd /path/to/glance
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/requirements.txt
python tools/convert_arcface.py --variant w600k_r50
```

(`--output PATH` writes the package somewhere other than `glance/Models/`.)
First run downloads the InsightFace `buffalo_l` model pack to
`~/.insightface/models/` (cached for next time). The script then:

1. Converts ONNX → torch → Core ML, baking preprocessing (RGB, `(px-127.5)/127.5`)
   into the model so Swift only ever hands over a raw 112×112 image.
2. **Verifies numerical parity**: runs the same random input through the
   original ONNX graph and the converted Core ML model and checks the
   outputs agree (cosine similarity > 0.999). This is the real check —
   a channel-order or scale mistake would silently produce a broken model
   that loads fine and returns plausible-looking garbage. If this check
   fails, the script exits with an error and **the model is not usable** —
   do not wire it in.
3. Saves `glance/Models/ArcFace.mlpackage`.

Expect it to take a few minutes, mostly the one-time package installs.

## After it succeeds

Add `glance/Models/ArcFace.mlpackage` to the Xcode project if it doesn't
show up automatically (the `glance/` folder is a file-system-synchronized
group, so it should auto-appear — if not, drag it into Xcode and make sure
"Copy items if needed" + the `glance` target are checked).

The model is committed to git (see the repo's `.gitignore` — only the
*compiled* `.mlmodelc` is excluded, since that's derived from the
`.mlpackage` at build time).

## If auto-download fails

InsightFace's model hosting occasionally moves. If `FaceAnalysis(...).prepare()`
fails, download `w600k_r50.onnx` (inside `buffalo_l.zip` on the InsightFace v0.7 release) yourself and
run:

```bash
python tools/convert_arcface.py --variant w600k_r50 --onnx-path /path/to/w600k_r50.onnx
```

## Model contract (what Swift expects)

| | |
|---|---|
| Input | `input_image`, 112×112 RGB image (CVPixelBuffer/CGImage) |
| Output | `embedding`, 512 floats, **not** L2-normalized — Swift normalizes it |
| Preprocessing | Baked in: `(pixel - 127.5) / 127.5`, RGB channel order |

The lighter `w600k_mbf` variant (MobileFaceNet, ~6.6MB, the script's default
`--variant`) satisfies the same contract; only file size and latency change.
Switching variants also requires a new `ArcFaceEmbedder.modelIdentifier`, which
flags existing enrollments for recapture.
