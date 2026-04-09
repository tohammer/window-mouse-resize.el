# window-mouse-resize

Resize Emacs windows by mouse drag.

## Usage

Hold **Ctrl+Shift** and drag with **mouse button 1** inside any window.
The position where you start the drag determines which edge moves:

| Start position | Edge moved        |
|----------------|-------------------|
| Left half      | Left edge         |
| Right half     | Right edge        |
| Top half       | Top edge          |
| Bottom half    | Bottom edge       |

Diagonal drags resize both axes proportionally to the drag distance.
Near-cardinal drags (within `window-mouse-resize-threshold` of horizontal
or vertical) only resize the dominant axis.

## Setup

### use-package

```elisp
(use-package window-mouse-resize
  :ensure t
  :config
  (window-mouse-resize-mode 1))
```

### Doom Emacs

In `packages.el`:

```elisp
(package! window-mouse-resize)
```

In `config.el`:

```elisp
(use-package! window-mouse-resize
  :config
  (window-mouse-resize-mode))
```

## Customization

| Variable                          | Default | Description                                                  |
|-----------------------------------|---------|--------------------------------------------------------------|
| `window-mouse-resize-scale`       | `1.0`   | Scale factor applied to mouse deltas. Set to `0.5` to halve speed. |
| `window-mouse-resize-threshold`   | `0.15`  | Fraction of dominant axis below which the minor axis is ignored. |
