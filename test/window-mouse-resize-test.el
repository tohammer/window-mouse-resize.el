;;; window-mouse-resize-test.el --- Tests for window-mouse-resize -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Run with:  make test
;;
;; The tests run in the batch frame, where one pixel is one character
;; cell.  The pointer position is stubbed; a drag is driven through
;; `window-mouse-resize-start' and the transient map it installs.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'window-mouse-resize)

(defconst window-mouse-resize-test--origin '(100 . 100)
  "Pointer position at the start of every simulated drag.")

(defvar window-mouse-resize-test--pointer window-mouse-resize-test--origin
  "Current simulated pointer position (X . Y).")

(defmacro window-mouse-resize-test--with-pointer (&rest body)
  "Run BODY with the pointer position read from the test variable."
  (declare (indent 0))
  `(let ((window-mouse-resize-test--pointer window-mouse-resize-test--origin))
     (cl-letf (((symbol-function 'mouse-absolute-pixel-position)
                (lambda () window-mouse-resize-test--pointer))
               ((symbol-function 'mouse-pixel-position)
                (lambda ()
                  (cons (selected-frame) window-mouse-resize-test--pointer))))
       ,@body)))

(defun window-mouse-resize-test--event (type window x y)
  "Return a mouse event of TYPE at X, Y in WINDOW's text area."
  (let ((pos (window-point window)))
    (list type (list window pos (cons x y) 0 nil pos
                     (cons x y) nil '(0 . 0) '(1 . 1)))))

(defun window-mouse-resize-test--press (window x y &optional type)
  "Start a drag in WINDOW at X, Y with a TYPE event (C-S-down-mouse-1)."
  (window-mouse-resize-start
   (window-mouse-resize-test--event (or type 'C-S-down-mouse-1) window x y)))

(defun window-mouse-resize-test--move (dx dy)
  "Move the pointer to DX, DY from the drag origin and run the handler."
  (setq window-mouse-resize-test--pointer
        (cons (+ (car window-mouse-resize-test--origin) dx)
              (+ (cdr window-mouse-resize-test--origin) dy)))
  (funcall (lookup-key overriding-terminal-local-map [mouse-movement])
           (list 'mouse-movement nil)))

(defun window-mouse-resize-test--release ()
  "Release the button, ending the drag."
  (funcall (lookup-key overriding-terminal-local-map [C-S-drag-mouse-1])))

(defun window-mouse-resize-test--drag (window x y &rest offsets)
  "Drag from X, Y in WINDOW through each (DX . DY) of OFFSETS, then release."
  (window-mouse-resize-test--with-pointer
    (window-mouse-resize-test--press window x y)
    (unwind-protect
        (dolist (o offsets)
          (window-mouse-resize-test--move (car o) (cdr o)))
      (window-mouse-resize-test--release))))

(defun window-mouse-resize-test--columns ()
  "Split the frame into two side-by-side windows; return (LEFT RIGHT)."
  (delete-other-windows)
  (let ((left (selected-window)))
    (list left (split-window-right))))

(defun window-mouse-resize-test--rows ()
  "Split the frame into two stacked windows; return (TOP BOTTOM)."
  (delete-other-windows)
  (let ((top (selected-window)))
    (list top (split-window-below))))

(defun window-mouse-resize-test--grid ()
  "Split the frame into four windows; return the top-left one."
  (delete-other-windows)
  (let ((top-left (selected-window)))
    (split-window-below)
    (split-window-right)
    top-left))

;;;; Which edge moves

(ert-deftest window-mouse-resize-test-right-edge ()
  (cl-destructuring-bind (left right) (window-mouse-resize-test--columns)
    (let ((lw (window-pixel-width left)) (rw (window-pixel-width right)))
      (window-mouse-resize-test--drag left 30 2 '(2 . 0) '(5 . 0))
      (should (= (window-pixel-width left) (+ lw 5)))
      (should (= (window-pixel-width right) (- rw 5))))))

(ert-deftest window-mouse-resize-test-left-edge ()
  (cl-destructuring-bind (left right) (window-mouse-resize-test--columns)
    (let ((lw (window-pixel-width left)) (rw (window-pixel-width right)))
      (window-mouse-resize-test--drag right 2 2 '(-2 . 0) '(-5 . 0))
      (should (= (window-pixel-width left) (- lw 5)))
      (should (= (window-pixel-width right) (+ rw 5))))))

(ert-deftest window-mouse-resize-test-bottom-edge ()
  (cl-destructuring-bind (top bottom) (window-mouse-resize-test--rows)
    (let ((th (window-pixel-height top)) (bh (window-pixel-height bottom)))
      (window-mouse-resize-test--drag top 10 8 '(0 . 1) '(0 . 3))
      (should (= (window-pixel-height top) (+ th 3)))
      (should (= (window-pixel-height bottom) (- bh 3))))))

(ert-deftest window-mouse-resize-test-top-edge ()
  (cl-destructuring-bind (top bottom) (window-mouse-resize-test--rows)
    (let ((th (window-pixel-height top)) (bh (window-pixel-height bottom)))
      (window-mouse-resize-test--drag bottom 10 1 '(0 . -1) '(0 . -3))
      (should (= (window-pixel-height top) (- th 3)))
      (should (= (window-pixel-height bottom) (+ bh 3))))))

(ert-deftest window-mouse-resize-test-frame-edge-does-not-move ()
  (delete-other-windows)
  (let* ((window (selected-window))
         (edges (window-pixel-edges window)))
    (window-mouse-resize-test--drag window 70 20 '(5 . 5) '(-30 . -10))
    (should (equal (window-pixel-edges window) edges))))

(ert-deftest window-mouse-resize-test-uses-clicked-window ()
  (cl-destructuring-bind (left right) (window-mouse-resize-test--columns)
    (select-window right)
    (let ((lw (window-pixel-width left)))
      (window-mouse-resize-test--drag left 30 2 '(5 . 0))
      (should (= (window-pixel-width left) (+ lw 5))))))

;;;; Following the pointer

(ert-deftest window-mouse-resize-test-scale-accumulates ()
  "Regression: with scale 0.5, 1-pixel motion events never moved the edge."
  (cl-destructuring-bind (left _right) (window-mouse-resize-test--columns)
    (let ((lw (window-pixel-width left))
          (window-mouse-resize-scale 0.5))
      (apply #'window-mouse-resize-test--drag left 30 2
             (mapcar (lambda (i) (cons i 0)) (number-sequence 1 10)))
      (should (= (window-pixel-width left) (+ lw 5))))))

(ert-deftest window-mouse-resize-test-threshold-uses-whole-drag ()
  "Regression: the threshold was applied to each motion event alone.
A drag of 22 right and 2 down (ratio 0.09) moved the bottom edge too,
because single events of (6 . 1) were above the threshold."
  (let* ((window (window-mouse-resize-test--grid))
         (w (window-pixel-width window))
         (h (window-pixel-height window)))
    (window-mouse-resize-test--drag window 30 8 '(6 . 1) '(12 . 2) '(22 . 2))
    (should (= (window-pixel-width window) (+ w 22)))
    (should (= (window-pixel-height window) h))))

(ert-deftest window-mouse-resize-test-diagonal-moves-both ()
  (let* ((window (window-mouse-resize-test--grid))
         (w (window-pixel-width window))
         (h (window-pixel-height window)))
    (window-mouse-resize-test--drag window 30 8 '(4 . 2) '(8 . 3))
    (should (= (window-pixel-width window) (+ w 8)))
    (should (= (window-pixel-height window) (+ h 3)))))

(ert-deftest window-mouse-resize-test-minor-axis-returns ()
  "An edge moved early in the drag goes back once its axis is minor."
  (let* ((window (window-mouse-resize-test--grid))
         (h (window-pixel-height window)))
    (window-mouse-resize-test--drag window 30 8 '(3 . 3) '(30 . 1))
    (should (= (window-pixel-height window) h))))

(ert-deftest window-mouse-resize-test-follows-pointer-after-limit ()
  "After hitting the minimum window size, the edge tracks the pointer again."
  (cl-destructuring-bind (left _right) (window-mouse-resize-test--columns)
    (let ((lw (window-pixel-width left)))
      (window-mouse-resize-test--drag left 30 2 '(60 . 0) '(5 . 0))
      (should (= (window-pixel-width left) (+ lw 5))))))

(ert-deftest window-mouse-resize-test-ignores-frame-relative-position ()
  "Regression: a pointer outside the frame made every motion event fail.
`mouse-pixel-position' returns nil coordinates there."
  (cl-destructuring-bind (left _right) (window-mouse-resize-test--columns)
    (let ((lw (window-pixel-width left)))
      (window-mouse-resize-test--with-pointer
        (window-mouse-resize-test--press left 30 2)
        (unwind-protect
            (cl-letf (((symbol-function 'mouse-pixel-position)
                       (lambda () (list (selected-frame)))))
              (window-mouse-resize-test--move 5 0))
          (window-mouse-resize-test--release)))
      (should (= (window-pixel-width left) (+ lw 5))))))

(ert-deftest window-mouse-resize-test-offsets ()
  (let ((window-mouse-resize-scale 1.0)
        (window-mouse-resize-threshold 0.15))
    (should (equal (window-mouse-resize--offsets 20 2) '(20 . 0)))
    (should (equal (window-mouse-resize--offsets 20 3) '(20 . 3)))
    (should (equal (window-mouse-resize--offsets -2 -20) '(0 . -20))))
  (let ((window-mouse-resize-threshold 0))
    (should (equal (window-mouse-resize--offsets 20 1) '(20 . 1))))
  (let ((window-mouse-resize-threshold 1))
    (should (equal (window-mouse-resize--offsets 20 19) '(20 . 0)))))

;;;; Ending the drag

(ert-deftest window-mouse-resize-test-swallows-any-release ()
  "Regression: only three hard-coded release events were swallowed.
A release with other modifiers, a click without motion, or the release
of a rebound trigger ran its global binding."
  (delete-other-windows)
  (window-mouse-resize-test--with-pointer
    (window-mouse-resize-test--press (selected-window) 5 5 'M-down-mouse-1)
    (unwind-protect
        (dolist (key '([M-drag-mouse-1] [S-drag-mouse-1] [drag-mouse-1]
                       [C-S-mouse-1] [mouse-1]))
          (should (lookup-key overriding-terminal-local-map key)))
      (window-mouse-resize-test--release))))

(ert-deftest window-mouse-resize-test-release-for-other-button ()
  (delete-other-windows)
  (window-mouse-resize-test--with-pointer
    (window-mouse-resize-test--press (selected-window) 5 5 'C-down-mouse-3)
    (let ((finish (lookup-key overriding-terminal-local-map [C-drag-mouse-3])))
      (unwind-protect
          (progn
            (should finish)
            (should-not (lookup-key overriding-terminal-local-map
                                    [C-drag-mouse-1])))
        (if finish (funcall finish) (window-mouse-resize-test--release))))))

(ert-deftest window-mouse-resize-test-release-cleans-up ()
  (delete-other-windows)
  (let ((track-mouse nil))
    (window-mouse-resize-test--with-pointer
      (window-mouse-resize-test--press (selected-window) 5 5)
      (unwind-protect
          (progn
            (should (eq track-mouse 'dragging))
            (should (lookup-key overriding-terminal-local-map
                                [mouse-movement])))
        (window-mouse-resize-test--release)))
    (should-not track-mouse)
    (should-not (and overriding-terminal-local-map
                     (lookup-key overriding-terminal-local-map
                                 [mouse-movement])))))

;;;; Minor mode

(defconst window-mouse-resize-test--trigger
  (if (eq system-type 'darwin) [S-s-down-mouse-1] [C-S-down-mouse-1])
  "The default trigger on the platform running the tests.")

(ert-deftest window-mouse-resize-test-mode-binds-trigger ()
  (unwind-protect
      (progn
        (window-mouse-resize-mode 1)
        (should (eq (key-binding window-mouse-resize-test--trigger)
                    #'window-mouse-resize-start))
        (window-mouse-resize-mode -1)
        (should-not (eq (key-binding window-mouse-resize-test--trigger)
                        #'window-mouse-resize-start)))
    (window-mouse-resize-mode -1)))

(ert-deftest window-mouse-resize-test-platform-bindings ()
  "One trigger per platform: Cmd-Shift (super) on macOS, C-S elsewhere."
  (dolist (system '(gnu/linux windows-nt darwin))
    (let* ((system-type system)
           (map (window-mouse-resize--make-mode-map))
           (mac (eq system 'darwin)))
      (should (eq (eq (lookup-key map [C-S-down-mouse-1])
                      #'window-mouse-resize-start)
                  (not mac)))
      (should (eq (eq (lookup-key map [S-s-down-mouse-1])
                      #'window-mouse-resize-start)
                  mac)))))

(ert-deftest window-mouse-resize-test-no-lighter ()
  (should-not (cadr (assq 'window-mouse-resize-mode minor-mode-alist))))

;;; window-mouse-resize-test.el ends here
