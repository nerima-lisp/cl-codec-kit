;;;; src/iso-8859-1.lisp
;;;;
;;;; ISO-8859-1 (Latin-1): one octet per character, codespace U+0000-U+00FF,
;;;; with every octet value mapping directly to the identical code point.
;;;; Every other ISO-8859-N variant (2 through 16) needs a real per-encoding
;;;; mapping table above the Basic Latin range and is deferred -- see the
;;;; project's docs/src/roadmap.md for what is and is not implemented.
(in-package #:cl-codec-kit)

;; No :DEFAULT-REPLACEMENT, for the reason given in ascii.lisp: #x1A (SUB) is
;; what babel's single-octet codecs substitute, and U+FFFD is outside this
;; codespace. Note that the decode direction can never need it -- every octet
;; value is a valid ISO-8859-1 character -- so only ISO-8859-1-ENCODE does.

(define-single-octet-encoding iso-8859-1 (:aliases (:latin-1 :latin1)))
