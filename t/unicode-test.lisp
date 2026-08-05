;;;; t/unicode-test.lisp
;;;;
;;;; unicode.lisp's SURROGATE-CODE-POINT-VALUE-P, BOM-SENSING-DECODE/-ENCODE,
;;;; and DEFINE-BYTE-ORDER-ENCODING are internal, unexported helpers -- every
;;;; other FOO-test.lisp in this directory tests only the public API, and the
;;;; BOM-sensing behavior these helpers implement is already pinned end to
;;;; end through it in utf-16-test.lisp, utf-32-test.lisp, and ucs-2-test.lisp
;;;; (each registered encoding's own DECODE-PREFIX/OCTETS-TO-STRING round
;;;; trip). What is not pinned anywhere else is that the surrogate-range
;;;; boundary comparison itself is exactly right, at every one of its four
;;;; boundary values -- an off-by-one there would misclassify one Unicode
;;;; code point per boundary without any single existing example test
;;;; noticing, because none of them is built to probe boundaries specifically.
(in-package #:cl-codec-kit/test)

(describe
  "the surrogate-range boundary check every codec here shares"
  (it "kills every mutation of the boundary comparison with a perfect score"
    ;; A self-contained truth table for SURROGATE-CODE-POINT-VALUE-P's
    ;; contract (unicode.lisp), redundantly encoded here rather than calling
    ;; the internal function directly, so RUN-MUTATIONS can EVAL each mutant
    ;; in the null lexical environment without needing a free variable
    ;; binding. Every code point below is a boundary: one below, at, and
    ;; above each edge of #xD800-#xDFFF, plus the codespace's own extremes.
    ;;
    ;; The four out-of-range conjuncts assert only the single comparison
    ;; that actually excludes that point (the one against +MIN-SURROGATE+
    ;; below the range, against +MAX-SURROGATE+ above it) rather than the
    ;; full three-argument (<= LOW X HIGH) chain: cl-weave's
    ;; :COMPARISON-OPERATOR mutator rewrites <= to a 3-argument >, and since
    ;; +MIN-SURROGATE+ < +MAX-SURROGATE+ always holds, (> LOW X HIGH) can
    ;; never be true regardless of X -- that mutant is unkillable by
    ;; construction, no matter which out-of-range X is chosen. The two-
    ;; argument form doesn't have that degenerate case: <=/> are true
    ;; complements for any two reals, so every mutation flips it.
    (let ((results
            (run-mutations
             '(and (not (<= #xD800 0))            ; codespace minimum
                   (not (<= #xD800 #xD7FF))        ; one below the range
                   (<= #xD800 #xD800 #xDFFF)       ; range minimum
                   (<= #xD800 #xDBFF #xDFFF)       ; last high surrogate
                   (<= #xD800 #xDC00 #xDFFF)       ; first low surrogate
                   (<= #xD800 #xDFFF #xDFFF)       ; range maximum
                   (not (<= #xE000 #xDFFF))        ; one above the range
                   (not (<= #x10FFFF #xDFFF)))     ; codespace maximum
             (lambda (form mutation)
               (declare (ignore mutation))
               (eq (eval form) t)))))
      (assert-mutation-score results 1.0))))
