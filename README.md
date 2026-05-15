# window-mouse-resize

Resize Emacs windows by mouse drag. Hold `C-S` and drag with mouse button 1 inside any window. Where the drag starts determines which edge moves.

| Start position | Edge moved   |
|----------------|--------------|
| Left half      | Left edge    |
| Right half     | Right edge   |
| Top half       | Top edge     |
| Bottom half    | Bottom edge  |

Diagonal drags resize both axes. Drags within `window-mouse-resize-threshold` of horizontal or vertical only affect the dominant axis.

## Installation

### use-package (Emacs 29+)

```elisp
(use-package window-mouse-resize
  :vc (:url "https://github.com/tohammer/window-mouse-resize.el")
  :config
  (window-mouse-resize-mode 1))
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

## Customization

| Variable                          | Default | Description                                                          |
|-----------------------------------|---------|----------------------------------------------------------------------|
| `window-mouse-resize-scale`       | `1.0`   | Scale factor applied to mouse deltas.                                |
| `window-mouse-resize-threshold`   | `0.15`  | Minor-axis fraction below which only the dominant axis is resized.   |

### Keybindings

Default triggers are `C-S-down-mouse-1` and `S-s-down-mouse-1` (macOS Cmd+Shift). The public command is `window-mouse-resize-start`. Customize via `window-mouse-resize-mode-map`:

```elisp
;; Add an additional trigger
(define-key window-mouse-resize-mode-map [M-down-mouse-1] #'window-mouse-resize-start)

;; Replace the default trigger
(define-key window-mouse-resize-mode-map [C-S-down-mouse-1] nil)
(define-key window-mouse-resize-mode-map [M-down-mouse-1] #'window-mouse-resize-start)
```

## AI Disclaimer

This package was developed with the help of AI coding agents.
