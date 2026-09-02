# Tutorial: Stable Diffusion via ComfyUI (Illustrious / Pony checkpoint)

Free, local alternative to Midjourney for character art. Companion to
`docs/art-direction.md` — use this to actually run the tag-based prompts
drafted there.

## 1. Requirements

- A GPU with **at least 6-8 GB VRAM** (NVIDIA strongly preferred — AMD
  works on Linux via ROCm but is more setup pain). No GPU? Skip to
  "No-GPU option" at the bottom.
- ~20 GB free disk space (ComfyUI + one checkpoint + outputs).
- Windows, Mac (Apple Silicon supported, slower), or Linux.

## 2. Install ComfyUI

1. Go to the official ComfyUI repo and download the **portable build**
   if you're on Windows (simplest — no Python setup needed), or clone
   the repo and follow its README for Mac/Linux (`pip install`-based).
2. Launch it once to confirm it opens a local web UI in your browser
   (usually `http://127.0.0.1:8188`) with the default node graph.

## 3. Get a checkpoint (the actual art model)

Checkpoints live on **Civitai** (civitai.com) and **Hugging Face**.
Pick one:

- **Illustrious XL** — strong, modern, versatile anime style, large
  LoRA ecosystem. Good default.
- **Pony Diffusion XL** — very flexible, huge community LoRA/style
  support, slightly more "stylized" default look than Illustrious.

Either works for Gatefall's style; try both on the same prompt and pick
whichever matches the "clean lineart, cel shading, semi-realistic
anime" direction from `docs/art-direction.md` once that's decided.

1. Download the checkpoint's `.safetensors` file (base model, several
   GB).
2. Move it into `ComfyUI/models/checkpoints/`.
3. Restart ComfyUI (or refresh the browser tab) so it's picked up.

## 4. Run your first generation

1. On first launch, ComfyUI loads a **default workflow graph** — nodes
   connected by lines: `Load Checkpoint` → `CLIP Text Encode (positive
   prompt)` + `CLIP Text Encode (negative prompt)` → `KSampler` → `VAE
   Decode` → `Save Image`.
2. In `Load Checkpoint`, select the checkpoint file you just added.
3. In the **positive prompt** box, paste a tag-based prompt (e.g.
   Faelen's draft in `docs/art-direction.md`).
4. In the **negative prompt** box, paste the negative tags (chibi,
   deformed, extra limbs, etc. — also in that doc).
5. Leave sampler defaults alone for the first run (Euler a / DPM++ 2M,
   ~25-30 steps, CFG ~6-7 are safe starting points for
   Illustrious/Pony — check the checkpoint's Civitai page, most list
   recommended settings).
6. Click **Queue Prompt**. First run is slow (model loading); later
   runs are much faster.
7. Image appears bottom-right and saves to `ComfyUI/output/`.

## 5. Getting a usable resolution

Illustrious/Pony are SDXL-based — generate at **1024x1024** or similar
SDXL-native resolutions (e.g. 832x1216 portrait, 1216x832 landscape)
rather than old SD1.5 sizes like 512x512, or quality drops noticeably.

## 6. Character consistency (the `--cref` equivalent)

Base SD has no built-in character-reference feature like Midjourney's
`--cref`. Two ways to get consistency once a design is locked:

- **img2img / ControlNet** — feed the locked model-sheet image back in
  at low denoise strength to keep pose/outfit while changing
  expression. Good for quick one-offs.
- **Train a LoRA** — the real solution for "many consistent assets of
  one character" (expression sets, battle sprites, splash art):
  1. Generate/curate 15-30 images of the locked design from different
     angles/expressions.
  2. Use a training tool — **Kohya_ss** (free, most common) or
     Civitai's online trainer (free tier available) — to train a small
     LoRA file on those images against your chosen checkpoint.
  3. Drop the resulting `.safetensors` LoRA into
     `ComfyUI/models/loras/`, add a `Load LoRA` node to your workflow,
     and reference it in prompts (e.g. `<lora:faelen_v1:0.8>`).
  4. Now every future generation of that character stays on-model
     without needing 30-tag descriptions each time.

Do this per character once its model sheet is locked — not before.

## 7. No-GPU option: Google Colab (recommended starting point)

No local GPU needed — Colab's free tier gives a Tesla T4, enough to
run ComfyUI + an SDXL checkpoint.

1. Open `docs/colab/gatefall_comfyui.ipynb` in this repo, either by
   uploading it to Google Drive and opening with Colab, or via
   `colab.research.google.com` -> `File` -> `Open notebook` -> `GitHub`
   tab -> paste this repo's URL and pick the notebook.
2. `Runtime` -> `Change runtime type` -> `T4 GPU` -> `Save`.
3. Run the cells top to bottom:
   - Cell 1 confirms the GPU is attached.
   - Cell 2 installs ComfyUI.
   - Cell 3 downloads a checkpoint — paste an Illustrious or Pony
     Diffusion XL download URL from Civitai (see the notebook's own
     instructions for where to find it; some models need a free
     Civitai API key too).
   - Cell 4 launches ComfyUI and prints a public link (Colab's own
     proxy by default, a `trycloudflare.com` link as fallback) — the
     same ComfyUI web UI described in step 4 of this doc. **Copy the
     link and paste it into a new tab's address bar rather than
     clicking it** — ComfyUI's own CSRF protection returns `403 —
     Access denied` for cross-site navigations, which clicking the
     link from inside the Colab page counts as; pasting into the
     address bar doesn't.
   - Paste prompts from `docs/art-direction.md` and generate as usual.
   - Last cell zips and downloads everything in `output/` before you
     close the session — **Colab wipes its disk when the session
     ends**, so don't skip this.
4. Free-tier limits: sessions disconnect after a period of inactivity
   and there's a rolling weekly GPU-time cap. Fine for exploration
   passes (model sheets, prompt iteration); if LoRA training or heavy
   batch generation becomes the bottleneck later, that's the point to
   consider Colab Pro or a local/rented GPU.

- **Civitai's online generator** is a lighter-weight alternative for
  just testing a prompt idea — free daily credits, same checkpoints,
  no notebook setup at all.

## 8. Suggested workflow for this project

1. Install ComfyUI + one checkpoint (this doc).
2. Run Faelen's draft prompt from `docs/art-direction.md`, iterate on
   the prompt until the look matches the intended house style.
3. Lock the winning prompt back into `docs/art-direction.md` and fill
   in "Global style" there.
4. Repeat model-sheet generation for Kess, Momo, Thora, Dana once the
   combat loop is proven (per `docs/HANDOFF.md` sequencing).
5. Train a LoRA per character once each design is locked, to mass
   produce the expression sets and battle sprites listed in the asset
   checklist.
