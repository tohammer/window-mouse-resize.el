# window-mouse-resize

Resize Emacs windows by dragging anywhere inside them, not only on the thin divider between them. Hold `C-S` (Control-Shift; on macOS also Cmd-Shift) and drag with the left mouse button. Where the drag starts picks the edges that move, so you can widen a side panel, shrink a compilation window or rebalance a split without aiming at the window border.

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

Split the frame (`C-x 3`), then `C-S`-drag in the right half of the left window to the right: the divider follows the pointer.

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
| `C-S-<down-mouse-1>`   | `window-mouse-resize-start` |
| `S-s-<down-mouse-1>`   | `window-mouse-resize-start` (macOS only: Cmd-Shift) |

Cmd-Shift is bound only on macOS, where Emacs reports Cmd as `super`. On Windows the Windows key is not a modifier by default, and GNOME (like many Linux window managers) uses Super-drag to move windows, so the binding would never reach Emacs there.

Bind `window-mouse-resize-start` to a button-down event. The drag ends when that button is released, whatever modifiers are still held.

```elisp
;; Add another trigger
(define-key window-mouse-resize-mode-map [M-down-mouse-1] #'window-mouse-resize-start)

;; Replace the default trigger
(define-key window-mouse-resize-mode-map [C-S-down-mouse-1] nil)
(define-key window-mouse-resize-mode-map [M-down-mouse-3] #'window-mouse-resize-start)
```

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
