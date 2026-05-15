;;; window-mouse-resize.el --- Resize windows by mouse drag -*- lexical-binding: t; -*-

;; Author: Tobias Hammer
;; Maintainer: Tobias Hammer
;; Version: 0.1
;; Package-Requires: ((emacs "28.1"))
;; Keywords: convenience, mouse, windows
;; URL: https://github.com/tohammer/window-mouse-resize.el
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Provides `window-mouse-resize-mode', a global minor mode that lets you
;; resize Emacs windows by holding C-S and dragging with mouse button 1.
;;
;; Where in the window the drag starts determines which edge moves:
;;   - Left half  → left edge (horizontal)
;;   - Right half → right edge (horizontal)
;;   - Top half   → top edge (vertical)
;;   - Bottom half → bottom edge (vertical)
;;
;; Diagonal drags resize both axes proportionally.  An axis whose
;; magnitude is less than `window-mouse-resize-threshold' times the
;; dominant axis is ignored so near-cardinal drags stay clean.
;;
;; Usage:
;;   (window-mouse-resize-mode 1)
;;
;; Customization:
;;   `window-mouse-resize-scale'        - scale factor (default 1.0)
;;   `window-mouse-resize-threshold'    - diagonal suppression threshold
;;   `window-mouse-resize-mode-map'     - keymap; rebind to change trigger keys

;;; Code:

(defgroup window-mouse-resize nil
  "Resize Emacs windows by mouse drag."
  :group 'windows
  :prefix "window-mouse-resize-")

(defcustom window-mouse-resize-scale 1.0
  "Scale factor applied to mouse deltas before resizing.
1.0 gives a 1:1 pixel mapping.  Reduce (e.g. 0.5) to slow down,
increase to speed up."
  :type 'float
  :group 'window-mouse-resize)

(defcustom window-mouse-resize-threshold 0.15
  "Axis-ignore threshold (0..1).
When the smaller drag axis is less than this fraction of the larger axis
it is ignored.  0 means always resize both axes; 1 means only the
dominant axis is ever resized."
  :type 'float
  :group 'window-mouse-resize)

;;; Core

(defun window-mouse-resize--apply (window dx dy left-half-p top-half-p)
  "Resize WINDOW edges based on drag deltas DX and DY.
LEFT-HALF-P and TOP-HALF-P indicate where the drag started.
Axes below `window-mouse-resize-threshold' of the dominant axis are ignored."
  (let* ((sdx (round (* dx window-mouse-resize-scale)))
         (sdy (round (* dy window-mouse-resize-scale)))
         (adx (abs sdx))
         (ady (abs sdy))
         (dom (max adx ady)))
    (when (> dom 0)
      (when (>= (/ adx (float dom)) window-mouse-resize-threshold)
        (ignore-errors
          (if left-half-p
              ;; Move left edge: grow/shrink the left neighbor by sdx.
              ;; Positive sdx (drag right) grows left-win → divider moves right → our window shrinks.
              (let ((left-win (window-in-direction 'left window t)))
                (when left-win
                  (adjust-window-trailing-edge left-win sdx t t)))
            ;; Move right edge: only if a right neighbor exists.
            (when (window-in-direction 'right window t)
              (adjust-window-trailing-edge window sdx t t)))))
      (when (>= (/ ady (float dom)) window-mouse-resize-threshold)
        (ignore-errors
          (if top-half-p
              ;; Move top edge: grow/shrink the window above by sdy.
              (let ((above-win (window-in-direction 'above window t)))
                (when above-win
                  (adjust-window-trailing-edge above-win sdy nil t)))
            ;; Move bottom edge: only if a window below exists.
            (when (window-in-direction 'below window t)
              (adjust-window-trailing-edge window sdy nil t))))))))

(defun window-mouse-resize-start (start-event)
  "Start resizing the window under mouse from START-EVENT."
  (interactive "e")
  (let* ((start-posn (event-start start-event))
         (window (posn-window start-posn)))
    (when (windowp window)
      (let* ((xy (posn-x-y start-posn))
             (win-w (window-pixel-width window))
             (win-h (window-pixel-height window))
             (left-half-p (< (car xy) (/ win-w 2)))
             (top-half-p  (< (cdr xy) (/ win-h 2)))
             (mpos (mouse-pixel-position))
             (last-x (cadr mpos))
             (last-y (cddr mpos))
             (old-track-mouse track-mouse)
             exitfun
             (move (lambda (event)
                     (interactive "e")
                     (ignore event)
                     (let* ((mpos (mouse-pixel-position))
                            (x (cadr mpos))
                            (y (cddr mpos))
                            (dx (- x last-x))
                            (dy (- y last-y)))
                       (setq last-x x last-y y)
                       (window-mouse-resize--apply
                        window dx dy left-half-p top-half-p)))))
        (setq track-mouse 'dragging)
        (setq exitfun
              (set-transient-map
               (let ((map (make-sparse-keymap)))
                 (define-key map [mouse-movement] move)
                 (define-key map [switch-frame] #'ignore)
                 (define-key map [select-window] #'ignore)
                 ;; Swallow drag-end regardless of modifier variant (macOS ns varies).
                 (define-key map [C-S-drag-mouse-1]
                   (lambda () (interactive) (funcall exitfun)))
                 (define-key map [S-s-drag-mouse-1]
                   (lambda () (interactive) (funcall exitfun)))
                 (define-key map [drag-mouse-1]
                   (lambda () (interactive) (funcall exitfun)))
                 (define-key map [mode-line] map)
                 (define-key map [header-line] map)
                 (define-key map [vertical-line] map)
                 (define-key map [right-divider] map)
                 (define-key map [bottom-divider] map)
                 map)
               t (lambda () (setq track-mouse old-track-mouse))))))))

;;; Minor mode

(defvar window-mouse-resize-mode-map (make-sparse-keymap)
  "Keymap for `window-mouse-resize-mode'.
Add or change bindings here to customize the trigger keys:

  (define-key window-mouse-resize-mode-map [C-S-down-mouse-1] nil)
  (define-key window-mouse-resize-mode-map [M-down-mouse-1]
              #\\='window-mouse-resize-start)")

(define-key window-mouse-resize-mode-map [C-S-down-mouse-1] #'window-mouse-resize-start)
(define-key window-mouse-resize-mode-map [S-s-down-mouse-1] #'window-mouse-resize-start)

;;;###autoload
(define-minor-mode window-mouse-resize-mode
  "Global minor mode to resize windows by mouse drag.
Hold C-S and drag with mouse button 1 to resize the window under the
mouse cursor.  The drag start position determines which edge moves:
left half = left edge, right half = right edge (same for vertical).
Diagonal drags resize both axes proportionally."
  :global t
  :lighter " WMR"
  :keymap window-mouse-resize-mode-map)

(provide 'window-mouse-resize)

;;; window-mouse-resize.el ends here
