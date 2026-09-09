---
name: screenshot
description: >
  Capture the screen on this Wayland/niri machine, so visual work can be checked rather than
  assumed. Use when you need to see what is currently displayed, verify a UI or theme change
  took effect, confirm a window opened or is positioned correctly, read something only visible
  on screen, or capture a region or a specific monitor. Covers which capture mechanisms work
  non-interactively, how to keep the file small enough to read, and how to handle the image
  afterwards.
---

# Taking a screenshot here

This machine runs **niri on Wayland**. Several obvious tools do not work here, and one of the
built-in bindings cannot be used non-interactively at all.

## What works, and what does not

| Mechanism | Usable without a human? |
|---|---|
| `grim <file>` | **Yes** — this is the one to use |
| `grim -g "X,Y WxH"` | **Yes** — region, with explicit numbers |
| `niri msg action screenshot-screen` / `-window` | Yes, but it writes to `~/Pictures/Screenshots/` with a timestamped name you then have to locate |
| `niri msg action screenshot` | **No** — opens an interactive UI and waits |
| `grim -g "$(slurp)"` | **No** — `slurp` waits for a human to drag a region |
| ImageMagick `import` | **No** — an X11 tool; captures nothing under Wayland |

`grim` is the Wayland capture tool. ImageMagick is installed (7.1.2, providing `magick` and the
legacy `convert`) and is for *processing* the result, never for taking it.

## Capture

```bash
grim "$SCRATCH/shot.png"                 # whole screen
grim -o eDP-1 "$SCRATCH/shot.png"        # one named output
grim -g "0,0 800x600" "$SCRATCH/r.png"   # region: "X,Y WxH"
```

Output names come from `niri msg outputs`. There is one built-in display, `eDP-1`, 1920x1200 at
scale 1 — confirm rather than assume it, since an external monitor changes this.

## Keep it small, but do not shrink it

A full PNG capture here is **1.8 MB**. Measured 2026-09-06 on this display:

| How | Result |
|---|---|
| PNG, full resolution | 1.8 MB |
| **JPEG q80, full resolution** | **173 KB** |
| JPEG q80 at 50% | 39 KB |
| PNG8, 64 colours | 356 KB |

**Re-encode rather than downscale when the point is to read something.** Downscaling destroys
text legibility; JPEG at full resolution is 10x smaller and keeps it. Downscale only when you
care about layout or window placement rather than content.

```bash
grim -t jpeg -q 80 "$SCRATCH/shot.jpg"                          # 173 KB, text readable
grim -o eDP-1 - | magick - -resize 50% "$SCRATCH/layout.png"    # layout only, no temp file
identify -format '%wx%h %[size]B\n' "$SCRATCH/shot.jpg"         # check before reading
```

Piping `grim -` into `magick -` avoids writing the full-size file at all.

## Capturing one specific window is harder than it looks

`niri msg --json windows` gives `app_id`, `title`, `pid` and a `layout` block — but the field
that would give an absolute screen rectangle, `tile_pos_in_workspace_view`, is **`null` for any
window not in the current view**. Verified 2026-09-06: all three open windows reported `null`.
So a window's screen coordinates cannot in general be computed from that output, and
`grim -g` cannot be aimed at it.

The options, in order of preference:

1. If the window is already visible, capture the whole screen and crop to the region you can
   see: `magick shot.png -crop 800x600+100+50 out.png`.
2. `niri msg action screenshot-window` captures the **focused** window — which means changing
   focus first, and that disturbs whatever the person is doing. Ask before doing it.
3. Do not focus-cycle through windows hunting for one. That is visible, disruptive, and slow.

`window_size` *is* reliable and is enough to answer "did this window open at the size I
expected" without capturing anything.

## Afterwards: read it, then delete it

A screenshot of this machine is a picture of someone's desktop — their mail, messages, whatever
happened to be open. Treat it as transient:

- Write to the session scratchpad, never `~/Pictures` (that is the person's own directory, and
  niri's bindings already use it).
- **Delete the file once it has been read.** Do not accumulate captures across a task.
- Capture the narrowest thing that answers the question — a region beats a full screen.
- Do not capture at all when a non-visual check would do. `niri msg windows` answers "did it
  open", `niri msg outputs` answers "what resolution", and neither takes a picture of anything.

If something unrelated and personal is visible, do not describe it, quote it, or act on it.
