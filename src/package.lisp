;;;; src/package.lisp
;;;;
;;;; The single public package. Layers build on each other in the order they
;;;; are loaded (per cl-codec-kit.asd's :serial t): conditions and registry
;;;; come first since every encoding depends on both; each encoding file
;;;; (utf-8, utf-16, utf-32, ucs-2, ascii, iso-8859-1) registers itself
;;;; independently of the others; streaming and api are built on the
;;;; registry alone, never on a specific encoding.
(defpackage #:cl-codec-kit
  (:use #:cl)
  (:export
   ;; Public API
   #:octets-to-string
   #:string-to-octets
   #:string-size-in-octets
   #:decode-prefix
   #:lenient-decode-prefix
   #:*default-encoding*
   #:list-character-encodings
   #:find-character-encoding
   ;; The one CHARACTER-ENCODING slot that is part of the public contract:
   ;; it is the value OCTETS-TO-STRING/STRING-TO-OCTETS/LENIENT-DECODE-PREFIX
   ;; substitute when :REPLACEMENT is omitted. Returns a CHARACTER, where
   ;; babel's similarly-named ENC-DEFAULT-REPLACEMENT returns a code point.
   #:character-encoding-default-replacement

   ;; Conditions
   #:cl-codec-kit-error
   #:decode-error
   #:decode-error-position
   #:unsupported-encoding
   #:unsupported-encoding-designator
   #:streaming-unsafe-encoding
   #:streaming-unsafe-encoding-designator
   #:invalid-leading-byte
   #:invalid-leading-byte-position
   #:invalid-leading-byte-octet
   #:invalid-continuation-byte
   #:invalid-continuation-byte-position
   #:invalid-continuation-byte-octet
   #:overlong-sequence
   #:overlong-sequence-position
   #:surrogate-code-point
   #:surrogate-code-point-position
   #:surrogate-code-point-value
   #:code-point-too-large
   #:code-point-too-large-position
   #:code-point-too-large-value
   #:truncated-sequence
   #:truncated-sequence-position
   #:unencodable-character
   #:unencodable-character-char
   #:unencodable-character-encoding
   #:unencodable-character-position))

(in-package #:cl-codec-kit)
