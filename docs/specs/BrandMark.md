# Specification — Brand mark exports (`docs/brand/`)

**Status:** specification, not yet implemented
**Target path:** `docs/brand/` (assets + README), `scripts/export-brand.sh`
**Written:** 2026-09-28
**Mark version:** v1 (approved shapes pinned below — copy exactly, do not redraw)

---

## Purpose

Put the AgentVault brand mark into the repo as source SVGs plus rendered PNGs,
with a repeatable export script and a short usage guide. Needed for the
Arbitrum Buildathon submission (deadline Oct 4) and every surface after it:
README, favicon, social avatars, demo video title card.

This is a documentation-and-assets task. No contract, no dependency added to
the monorepo's packages, nothing deployed.

## What the mark means

The **wheel pack** of a combination lock, shown in its **resting state:
locked**. Three wheels; the top two gates and the inner gate line up, the
middle gate is turned away, so the fence (amber bar) rests on the middle
wheel and cannot drop.

Maps to the product sentence: *the AI proposes, code decides.* Every check must
align before anything passes; one misaligned check blocks it. What is "locked"
is the agent's authority — not user funds. Never describe the mark as a vault
holding assets.

The aligned state (all gates up, fence dropped) exists as a **UI state**, not a
logo. See "States" below.

---

## Colour tokens

| Token | Hex | Use |
|---|---|---|
| `av-ground` | `#0F1210` | Dark tile background |
| `av-ink` | `#ECE6D6` | Wheels on dark |
| `av-amber` | `#F2A900` | Fence on dark |
| `av-ground-light` | `#F4F1EA` | Light tile background |
| `av-ink-light` | `#141413` | Wheels on light |
| `av-amber-light` | `#B37A00` | Fence on light (darker for contrast) |

**No red anywhere in the brand.** The resting state must read as "held", not
"error".

---

## Pinned sources — copy byte-for-byte

Three hand-tuned masters. Each small size is **drawn for its own pixel grid**.
Never produce the 16 or 32 px PNG by downscaling the 512 — that is the single
most likely way to break this task.

### `docs/brand/svg/agentvault-mark.svg` (master, dark tile)

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>AgentVault mark</title>
  <rect width="512" height="512" fill="#0F1210"/>
  <g fill="none" stroke="#ECE6D6" stroke-width="28" stroke-linecap="butt">
    <path d="M280 81.64 A176 176 0 1 1 232 81.64"/>
    <path d="M280 138.42 A120 120 0 1 1 232 138.42" transform="rotate(40 256 256)"/>
    <path d="M280 196.67 A64 64 0 1 1 232 196.67"/>
  </g>
  <rect x="242" y="36" width="28" height="72" fill="#F2A900"/>
</svg>
```

### `docs/brand/svg/agentvault-mark-32.svg`

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
  <title>AgentVault mark (32 px)</title>
  <rect width="32" height="32" fill="#0F1210"/>
  <g fill="none" stroke="#ECE6D6" stroke-width="2" stroke-linecap="butt">
    <path d="M18 4.17 A12 12 0 1 1 14 4.17"/>
    <path d="M18 8.25 A8 8 0 1 1 14 8.25" transform="rotate(45 16 16)"/>
    <path d="M18 12.54 A4 4 0 1 1 14 12.54"/>
  </g>
  <rect x="15" y="1" width="2" height="5" fill="#F2A900"/>
</svg>
```

### `docs/brand/svg/agentvault-mark-16.svg`

Two wheels, not three — three cannot resolve at 16 px. The inner gate is turned
180° (to the bottom); at 90° it read as a © symbol, at 45° as a refresh icon.

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
  <title>AgentVault mark (16 px)</title>
  <rect width="16" height="16" fill="#0F1210"/>
  <g fill="none" stroke="#ECE6D6" stroke-width="2" stroke-linecap="butt">
    <path d="M10 2.34 A6 6 0 1 1 6 2.34"/>
    <path d="M9.5 5.4 A3 3 0 1 1 6.5 5.4" transform="rotate(180 8 8)"/>
  </g>
  <rect x="7" y="0" width="2" height="4" fill="#F2A900"/>
</svg>
```

### Derived variants (generate from the master — geometry unchanged)

- `docs/brand/svg/agentvault-mark-light.svg` — master with background
  `#F4F1EA`, wheel stroke `#141413`, fence `#B37A00`.
- `docs/brand/svg/agentvault-mark-transparent.svg` — master with the
  background `<rect>` removed. Cream ink: **dark backgrounds only.** State
  this in a comment inside the file.

Only colours and the background rect may differ from the master. Every `d`,
`transform`, `x`, `y`, `width`, `height` and `stroke-width` stays identical.

---

## Rendered PNGs — `docs/brand/png/`

| File | Rendered from | Size |
|---|---|---|
| `agentvault-mark-16.png` | `agentvault-mark-16.svg` | 16×16 |
| `agentvault-mark-32.png` | `agentvault-mark-32.svg` | 32×32 |
| `agentvault-mark-64.png` | master | 64×64 |
| `agentvault-mark-180.png` | master | 180×180 (Apple touch icon) |
| `agentvault-mark-256.png` | master | 256×256 |
| `agentvault-mark-512.png` | master | 512×512 |
| `agentvault-mark-1024.png` | master | 1024×1024 (social / submission) |
| `agentvault-mark-light-512.png` | light variant | 512×512 |

Size rule for anyone using the mark: **≤ 24 px → 16 file; 25–63 px → 32
file; ≥ 64 px → master.**

---

## Export script — `scripts/export-brand.sh`

- Renderer: `rsvg-convert` (from the `librsvg` package). On macOS:
  `brew install librsvg`. This **installs software**, needs no admin rights,
  costs nothing, touches no blockchain, exposes no secrets. Explain this to
  the builder before running it.
- Script checks `rsvg-convert` exists and exits with a clear message if not.
- Script writes the derived SVGs and renders every PNG in the table.
- `set -euo pipefail`. Idempotent: running twice produces the same files.
- Does **not** modify the three pinned SVGs.
- Add no npm or Python dependency for this.

Run from the repo root: `bash scripts/export-brand.sh`

---

## `docs/brand/README.md`

Short, plain-language guide. Must cover:

1. What the mark depicts and why (the "What the mark means" section, condensed)
2. Colour tokens table
3. Size rule (which file at which size)
4. Clear space: at least one outer-wheel stroke width on every side
5. Don'ts: no rotating the mark, no recolouring the fence red or green, no
   labelling individual wheels as specific risk checks (the engine's check
   count will change), no gradients or glow, don't place the transparent
   variant on light backgrounds
6. **States** (for the future UI, not built now):
   - **Resting / blocked** = this mark
   - **Passed** = all three gates aligned, fence dropped through (to be drawn
     with the frontend milestone)
   - Any animation must show **both** outcomes, not only the pass, and must
     respect `prefers-reduced-motion` by showing the static mark
7. How to regenerate: the one command above

---

## Decision record

Append to `docs/DECISIONS.md`:

> **D15 — Brand mark: wheel pack, resting (locked) state (2026-09-28)**
> **Decided:** Combination-lock wheel pack with one gate misaligned and the
> fence held. Hand-tuned 16 / 32 / 512 masters.
> **Why:** Depicts the product sentence — every check must align before
> anything passes. What is locked is the agent's authority, not funds, which
> keeps the mark consistent with the noncustodial position. Kept separate from
> the Genesis NFT art so art direction can change without a rebrand.
> **Rejected:** encryption imagery (the record is public and tamper-evident,
> not secret); exploded mechanism as the icon (fails below 32 px — reserved for
> illustration); padlock and keypad (generic).
> **Cost:** Needs explanation the first time it is seen.
> **Reverses if:** Product stops being about constrained agent authority.

---

## Acceptance criteria

- [ ] Three pinned SVGs committed byte-for-byte as above
- [ ] Two derived SVGs differ from the master only in colours / background rect
- [ ] All eight PNGs exist at exactly the listed pixel dimensions
      (verify: `sips -g pixelWidth -g pixelHeight docs/brand/png/*.png`)
- [ ] 16 and 32 PNGs rendered from their own SVGs, not from the master
- [ ] `bash scripts/export-brand.sh` runs clean on a fresh clone after
      `brew install librsvg`, and a second run changes nothing
      (verify: `git status` shows no changes after the second run)
- [ ] `docs/brand/README.md` covers all seven points
- [ ] D15 appended to `docs/DECISIONS.md`; nothing else in that file changed
- [ ] No new package dependencies; `forge test` still passes
- [ ] Visual check: open the 16, 32 and 512 PNGs and confirm they match the
      approved canvas

## Deferred — do not build now

- Passed-state mark and the UI animation (frontend milestone)
- `favicon.ico` multi-size bundle (needs ImageMagick; add when the frontend exists)
- Wordmark / lockup with the name
- Exploded-view illustration for README hero or video title card
