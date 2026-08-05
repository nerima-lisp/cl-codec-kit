;;;; src/ascii.lisp
;;;;
;;;; 7-bit ASCII: the simplest encoding here, one octet per character,
;;;; codespace U+0000-U+007F. No multi-byte sequence exists, so no
;;;; TRUNCATED-SEQUENCE case applies -- every octet decodes independently.
(in-package #:cl-codec-kit)

;; No :DEFAULT-REPLACEMENT: ASCII takes DEFINE-ENCODING's own #x1A (SUB)
;; default, which is both what babel's single-octet codecs substitute and the
;; only choice encodable here -- U+FFFD is outside this codespace entirely.

(define-single-octet-encoding ascii (:aliases (:us-ascii) :max-code-point #x7F))
