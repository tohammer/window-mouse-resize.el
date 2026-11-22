# window-mouse-resize

[![test](https://github.com/tohammer/window-mouse-resize.el/actions/workflows/test.yml/badge.svg)](https://github.com/tohammer/window-mouse-resize.el/actions/workflows/test.yml)

Resize Emacs windows by dragging anywhere inside them, not only on the thin divider between them. Hold `C-S` (Control-Shift; Cmd-Shift on macOS) and drag with the left mouse button. Where the drag starts picks the edges that move, so you can widen a side panel, shrink a compilation window or rebalance a split without aiming at the window border.

| Drag starts in | Edge moved  |
|----------------|-------------|
| Left half      | Left edge   |
| Right half     | Right edge  |
| Top half       | Top edge    |
| Bottom half    | Bottom edge |

A diagonal drag moves one horizontal and one vertical edge. When the drag is close to horizontal or vertical, only the dominant axis is resized (see `window-mouse-resize-threshold`). Edges on the frame border don't move.

## Quick start

```elisp
(require 'window-mouse-resize)
(window-mouse-resize-mode 1)
```

Split the frame (`C-x 3`), then `C-S`-drag (Cmd-Shift-drag on macOS) in the right half of the left window to the right: the divider follows the pointer.

## Installation

Requires Emacs 28.1 or later and a graphical frame.

### use-package (Emacs 30+)

```elisp
(use-package window-mouse-resize
  :vc (:url "https://github.com/tohammer/window-mouse-resize.el")
  :config
  (window-mouse-resize-mode 1))
```

### package-vc (Emacs 29)

```elisp
(package-vc-install "https://github.com/tohammer/window-mouse-resize.el")
(window-mouse-resize-mode 1)
```

### Doom Emacs

In `packages.el`:

```elisp
(package! window-mouse-resize
  :recipe (:host github :repo "tohammer/window-mouse-resize.el"))
```

In `config.el`:

```elisp
(use-package! window-mouse-resize
  :config
  (window-mouse-resize-mode 1))
```

## Configuration

| Variable                        | Default | Description                                                                          |
|---------------------------------|---------|--------------------------------------------------------------------------------------|
| `window-mouse-resize-scale`     | `1.0`   | How far edges move per pixel of pointer movement. `0.5` for finer control.           |
| `window-mouse-resize-threshold` | `0.15`  | The minor axis is ignored while it is less than this fraction of the dominant axis. `0` always resizes both, `1` only ever the dominant one. |

```elisp
(setq window-mouse-resize-scale 0.5
      window-mouse-resize-threshold 0.3)
```

## Keys

Bindings in `window-mouse-resize-mode-map`, active while `window-mouse-resize-mode` is on:

| Key                    | Command                     |
|------------------------|-----------------------------|
| `C-S-<down-mouse-1>`   | `window-mouse-resize-start` (Linux, Windows) |
| `S-s-<down-mouse-1>`   | `window-mouse-resize-start` (macOS: Cmd-Shift) |

Only one of the two is bound, depending on the platform. On macOS, Emacs reports Cmd as `super`, and Cmd-Shift is the natural modifier there. Elsewhere Super is not used: on Windows the Windows key is not a modifier by default, and GNOME (like many Linux window managers) uses Super-drag to move windows, so the binding would never reach Emacs.

Bind `window-mouse-resize-start` to a button-down event. The drag ends when that button is released, whatever modifiers are still held.

```elisp
;; Add another trigger
(define-key window-mouse-resize-mode-map [M-down-mouse-1] #'window-mouse-resize-start)

;; Replace the default trigger (on macOS: [S-s-down-mouse-1])
(define-key window-mouse-resize-mode-map [C-S-down-mouse-1] nil)
(define-key window-mouse-resize-mode-map [M-down-mouse-3] #'window-mouse-resize-start)
```

### Mouse-only trigger

The trigger doesn't need a modifier key. A spare mouse button, such as a thumb (side) button, can start a drag on its own:

```elisp
(define-key window-mouse-resize-mode-map [down-mouse-8] #'window-mouse-resize-start)
```

The event name depends on the mouse and the platform. On Linux (X11) the thumb buttons are usually `mouse-8` and `mouse-9`; other systems may number them differently. Check which event your button sends before binding it:

- `M-: (list (read-event) (read-event))`, then press and release the button once. The result shows the press and the release, e.g. `((down-mouse-8 …) (mouse-8 …))`. Bind the `down-` event.
- Or press the button, then `C-h l` (`view-lossage`) to see the recent input events.

If Emacs sees nothing, the operating system or the mouse driver keeps the button for itself. On Linux, `xev` shows whether a press arrives at all (`ButtonPress … button 8`). On Windows, the side buttons reach Emacs only while `w32-pass-extra-mouse-buttons-to-system` is nil, the default.

Some modes use these buttons themselves, e.g. `eww` binds `mouse-8` to "back". With the binding above, pressing the button starts a drag and its release ends it, so the mode's own action no longer runs.

## Development

```sh
make          # byte-compile (warnings are errors), checkdoc, run tests
make test     # ERT tests only
```

Implementation notes are in [docs/architecture.md](docs/architecture.md).

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

## AI Disclaimer

This package was developed with the help of AI coding agents.
