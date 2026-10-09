EMACS ?= emacs
BATCH  = $(EMACS) -Q --batch -L . --eval '(setq load-prefer-newer t)'

.PHONY: all compile checkdoc test clean

all: compile checkdoc test

compile:
	$(BATCH) --eval '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile window-mouse-resize.el

checkdoc:
	$(BATCH) --eval '(checkdoc-file "window-mouse-resize.el")'

test:
	$(BATCH) -l test/window-mouse-resize-test.el -f ert-run-tests-batch-and-exit

clean:
	rm -f *.elc test/*.elc
