;;; window-mouse-resize.el --- Resize windows by mouse drag -*- lexical-binding: t; -*-

;; Author: Tobias Hammer <tohammer@users.noreply.github.com>
;; Maintainer: Tobias Hammer <tohammer@users.noreply.github.com>
;; Copyright (C) 2025 Tobias Hammer
;; Version: 0.3
;; Package-Requires: ((emacs "28.1"))
;; Keywords: convenience, mouse, windows
;; URL: https://github.com/tohammer/window-mouse-resize.el
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Provides `window-mouse-resize-mode', a global minor mode that lets you
;; resize Emacs windows by holding C-S (Cmd-Shift on macOS) and dragging
;; with mouse button 1 anywhere inside a window, not only on its divider.
;;
;; Where in the window the drag starts determines which edges move:
;;   - Left half   → left edge,   right half  → right edge
;;   - Top half    → top edge,    bottom half → bottom edge
;;
;; The moved edges follow the pointer for the whole drag.  When the drag
;; is close to horizontal or vertical, the minor axis is ignored (see
;; `window-mouse-resize-threshold').
;;
;; Usage:
;;   (window-mouse-resize-mode 1)
;;
;; Customization:
;;   `window-mouse-resize-scale'        - pointer-to-edge speed (default 1.0)
;;   `window-mouse-resize-threshold'    - minor-axis suppression threshold
;;   `window-mouse-resize-mode-map'     - keymap; rebind to change trigger keys

;;; Code:

(require 'cl-lib)

(defgroup window-mouse-resize nil
  "Resize Emacs windows by mouse drag."
  :group 'windows
  :prefix "window-mouse-resize-")

(defcustom window-mouse-resize-scale 1.0
  "Factor by which window edges move relative to the pointer.
1.0 moves an edge by as many pixels as the pointer moved.  Reduce
\(e.g. 0.5) for finer control, increase to resize faster."
  :type 'number
  :group 'window-mouse-resize)

(defcustom window-mouse-resize-threshold 0.15
  "Fraction below which the minor drag axis is ignored (0..1).
The pointer offset from the drag start is compared per axis.  When the
smaller offset is less than this fraction of the larger one, the edge on
that axis stays where it was when the drag started.  0 means always
resize both axes; 1 means only the dominant axis is ever resized."
  :type 'number
  :group 'window-mouse-resize)

;;; Core

(cl-defstruct (window-mouse-resize--drag
               (:constructor window-mouse-resize--drag-create)
               (:copier nil))
  "State of one drag.
ORIGIN is the absolute pointer position (X . Y) at the start.
H-WINDOW and V-WINDOW are the windows whose trailing edge is moved
horizontally and vertically, or nil.  H-START and V-START are those
edges' pixel positions at the start."
  origin h-window h-start v-window v-start)

(defun window-mouse-resize--edge-window (window direction)
  "Return the window whose trailing edge is WINDOW's DIRECTION edge.
DIRECTION is `left', `right', `above' or `below'.  Return nil when that
edge is a frame edge and cannot move."
  (let ((neighbor (window-in-direction direction window t)))
    (and neighbor
         (if (memq direction '(left above)) neighbor window))))

(defun window-mouse-resize--edge-position (window horizontal)
  "Return the pixel position of WINDOW's trailing edge.
HORIZONTAL non-nil means the right edge, nil the bottom edge."
  (nth (if horizontal 2 3) (window-pixel-edges window)))

(defun window-mouse-resize--move-edge (window horizontal target)
  "Move WINDOW's trailing edge as close as possible to pixel TARGET.
HORIZONTAL is as in `window-mouse-resize--edge-position'.  Window size
limits may stop the edge short of TARGET."
  (when (window-live-p window)
    (let ((delta (- target (window-mouse-resize--edge-position
                            window horizontal))))
      (unless (zerop delta)
        (condition-case nil
            (adjust-window-trailing-edge window delta horizontal t)
          (error nil))))))

(defun window-mouse-resize--offsets (dx dy)
  "Return (SX . SY), the edge offsets for pointer offset DX, DY.
Both are scaled by `window-mouse-resize-scale'; the minor axis is set
to 0 when it falls below `window-mouse-resize-threshold'."
  (let* ((sx (round (* dx window-mouse-resize-scale)))
         (sy (round (* dy window-mouse-resize-scale)))
         (limit (* window-mouse-resize-threshold (max (abs sx) (abs sy)))))
    (cons (if (< (abs sx) limit) 0 sx)
          (if (< (abs sy) limit) 0 sy))))

(defun window-mouse-resize--update (drag position)
  "Move the edges of DRAG to follow the pointer at absolute POSITION."
  (let* ((origin (window-mouse-resize--drag-origin drag))
         (offsets (window-mouse-resize--offsets
                   (- (car position) (car origin))
                   (- (cdr position) (cdr origin)))))
    (when (window-mouse-resize--drag-h-window drag)
      (window-mouse-resize--move-edge
       (window-mouse-resize--drag-h-window drag) t
       (+ (window-mouse-resize--drag-h-start drag) (car offsets))))
    (when (window-mouse-resize--drag-v-window drag)
      (window-mouse-resize--move-edge
       (window-mouse-resize--drag-v-window drag) nil
       (+ (window-mouse-resize--drag-v-start drag) (cdr offsets))))))

(defun window-mouse-resize--release-events (button)
  "Return every click and drag event of BUTTON, with any modifiers.
BUTTON is a basic event type such as `mouse-1'."
  (let ((combinations '(nil)))
    (dolist (modifier '(control meta shift super hyper alt))
      (setq combinations
            (append combinations
                    (mapcar (lambda (c) (cons modifier c)) combinations))))
    (mapcan (lambda (modifiers)
              (list (event-convert-list (append modifiers (list button)))
                    (event-convert-list
                     (append modifiers (list 'drag button)))))
            combinations)))

(defun window-mouse-resize-start (start-event)
  "Resize the window under the mouse by dragging, from START-EVENT.
Bind this to a mouse button-down event.  The half of the window in
which the drag starts selects the edges that move."
  (interactive "e")
  (let* ((start-posn (event-start start-event))
         (window (posn-window start-posn)))
    (when (window-live-p window)
      (let* ((xy (posn-x-y start-posn))
             (h-window (window-mouse-resize--edge-window
                        window (if (< (car xy) (/ (window-body-width window t) 2))
                                   'left 'right)))
             (v-window (window-mouse-resize--edge-window
                        window (if (< (cdr xy) (/ (window-body-height window t) 2))
                                   'above 'below)))
             (drag (window-mouse-resize--drag-create
                    :origin (mouse-absolute-pixel-position)
                    :h-window h-window
                    :h-start (and h-window (window-mouse-resize--edge-position
                                            h-window t))
                    :v-window v-window
                    :v-start (and v-window (window-mouse-resize--edge-position
                                            v-window nil))))
             (old-track-mouse track-mouse)
             (map (make-sparse-keymap))
             exitfun)
        (define-key map [mouse-movement]
          (lambda (_event)
            (interactive "e")
            (window-mouse-resize--update drag (mouse-absolute-pixel-position))))
        (define-key map [switch-frame] #'ignore)
        (define-key map [select-window] #'ignore)
        ;; Swallow the release of the start button whatever modifiers are
        ;; held by then, so it does not run a global binding.
        (let ((finish (lambda () (interactive) (funcall exitfun))))
          (dolist (event (window-mouse-resize--release-events
                          (event-basic-type start-event)))
            (define-key map (vector event) finish)))
        ;; The pointer may cross a mode line, header line or divider, so
        ;; events can arrive with one of those prefixes.
        (dolist (prefix '(mode-line header-line vertical-line
                          right-divider bottom-divider))
          (define-key map (vector prefix) map))
        (setq track-mouse 'dragging)
        (setq exitfun
              (set-transient-map
               map t (lambda () (setq track-mouse old-track-mouse))))))))

;;; Minor mode

(defvar window-mouse-resize-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [C-S-down-mouse-1] #'window-mouse-resize-start)
    (define-key map [S-s-down-mouse-1] #'window-mouse-resize-start)
    map)
  "Keymap for `window-mouse-resize-mode'.
Add or change bindings here to customize the trigger keys:

  (define-key window-mouse-resize-mode-map [C-S-down-mouse-1] nil)
  (define-key window-mouse-resize-mode-map [M-down-mouse-1]
              #\\='window-mouse-resize-start)

Bind button-down events; the matching release ends the drag.")

;;;###autoload
(define-minor-mode window-mouse-resize-mode
  "Global minor mode to resize windows by mouse drag.
\\<window-mouse-resize-mode-map>\
Drag with \\[window-mouse-resize-start] inside a window to resize it.
The half of the window in which the drag starts selects the edges
that move: left half moves the left edge, right half the right edge,
and the same for top and bottom.

\\{window-mouse-resize-mode-map}"
  :global t
  :keymap window-mouse-resize-mode-map)

(provide 'window-mouse-resize)

;;; window-mouse-resize.el ends here
