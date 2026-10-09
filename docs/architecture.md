# Architecture and implementation notes

This document describes how `window-mouse-resize` works and the Emacs
behaviours it depends on. Read it before changing how a drag is tracked
or ended.

## Overview

```
C-S-down-mouse-1 → window-mouse-resize-start (window from the event)
  ├─ pick edges from the start position in the window body:
  │    left half  → trailing edge of the window to the left
  │    right half → own trailing edge (only if a window is to the right)
  │    top/bottom → same, vertically
  ├─ record pointer origin (absolute) and each edge's start position
  ├─ track-mouse ← dragging
  └─ set-transient-map, kept while events are in the map:
       mouse-movement     → window-mouse-resize--update
       release of button  → end drag (any modifiers, click or drag)
       switch-frame, select-window → ignore
       mode-line, header-line, vertical-line, right/bottom-divider → map
     on exit: restore track-mouse
```

Emacs moves edges only through `adjust-window-trailing-edge`. A window's
left edge is the trailing edge of its left neighbour, so a left-half drag
adjusts that neighbour (`window-mouse-resize--edge-window`). An edge on
the frame border has no window on the other side and is not moved.

## Following the pointer

On every motion event the package computes the pointer offset from the
drag **origin**, scales it, drops the minor axis if needed
(`window-mouse-resize--offsets`), and moves each edge to
`start position + offset` (`window-mouse-resize--move-edge`). The edge
is moved by the difference between that target and where the edge is
now.

Version 0.1 instead resized by each motion event's own delta. That had
three bugs:

- **Rounding loss.** Deltas were scaled and rounded per event. With
  `window-mouse-resize-scale` 0.5, a 1-pixel event rounds to 0 (`round`
  rounds half to even), so slow drags never moved anything. Test:
  `window-mouse-resize-test-scale-accumulates`.
- **Threshold per event.** The minor-axis threshold compared the two
  axes of a single event. Motion events are a few pixels each, so a
  near-horizontal drag produced events like `(6 . 1)` that passed the
  threshold and moved the vertical edge as well. Tests:
  `window-mouse-resize-test-threshold-uses-whole-drag`,
  `window-mouse-resize-test-minor-axis-returns`.
- **Drift at size limits.** When a window hit its minimum size, the
  requested delta was lost; moving back then moved the edge away from
  the pointer. Targeting an absolute position keeps edge and pointer
  in step. Test: `window-mouse-resize-test-follows-pointer-after-limit`.

The pointer is read with `mouse-absolute-pixel-position`. 0.1 used
`mouse-pixel-position`, which returns nil coordinates when the pointer
leaves the frame, so every motion event outside the frame signalled
`wrong-type-argument`. Test:
`window-mouse-resize-test-ignores-frame-relative-position`.

`adjust-window-trailing-edge` signals an error when an edge cannot move
(minimum size, fixed-size window). `--move-edge` ignores those errors;
the edge simply stays put.

## Ending the drag

The transient map is installed with `KEEP-PRED` `t`: it stays active
while the incoming events have bindings in it, and is removed by the
first event that has none. That event is then looked up in the normal
keymaps.

The release of the button must therefore be in the map, or it leaks
through to a global binding. 0.1 bound only `C-S-drag-mouse-1`,
`S-s-drag-mouse-1` and `drag-mouse-1`. Releasing after letting go of
Control (`S-drag-mouse-1`), a click without motion (`C-S-mouse-1`), and
the release of a rebound trigger all leaked; with the README's own
`M-down-mouse-1` example the release ran `mouse-set-secondary`.

Now `window-mouse-resize--release-events` binds the click and drag
event of the *start event's* button with every combination of the six
modifiers (128 bindings per drag). Tests:
`window-mouse-resize-test-swallows-any-release`,
`window-mouse-resize-test-release-for-other-button`.

The map binds itself under the mode-line, header-line and divider
prefixes because a motion or release event over those areas arrives as
a two-event sequence such as `[mode-line mouse-movement]`. This mirrors
`mouse-drag-line` in Emacs's `mouse.el`.

## Which window is resized

The command takes the window from the event's `posn`, not the selected
window, so a drag in an unselected window resizes that window. The half
is decided from `posn-x-y`, which is relative to the text area, against
the window body size. Test:
`window-mouse-resize-test-uses-clicked-window`.

## Testing

`make test` runs the ERT suite under `emacs -Q --batch`. In batch the
frame is a terminal frame where one pixel is one character cell, which
is enough to exercise `adjust-window-trailing-edge`. The tests stub
the pointer position, start a drag with a synthetic event, and call the
bindings of the installed transient map directly. `make compile`
byte-compiles with warnings as errors; `make checkdoc` lints docstrings.

## Known limitations

- The automated tests run headless only; drags in a graphical frame
  need a manual check. Text terminals (`xterm-mouse-mode`) are untested.
- With more than one window along an edge, `window-in-direction` picks
  the neighbour next to the window's point. Moving its trailing edge
  moves the shared edge as Emacs defines it for that window
  combination.
- `track-mouse` is set globally and restored when the transient map
  exits, as `mouse-drag-line` does.

## Open points

- The `WMR` lighter is shown for a global mode that rarely needs to be
  visible. Dropping it changes the mode line for existing users.
