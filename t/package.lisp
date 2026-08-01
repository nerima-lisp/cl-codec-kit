;;;; t/package.lisp
(defpackage #:cl-codec-kit/test (:use #:cl)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   #:it #:expect #:signals #:run-all
   #:it-property #:gen-integer #:gen-list #:gen-boolean #:gen-map #:gen-such-that)
  (:import-from #:cl-codec-kit
   #:octets-to-string #:string-to-octets #:string-size-in-octets #:decode-prefix
   #:*default-encoding* #:list-character-encodings
   #:find-character-encoding
   #:cl-codec-kit-error #:decode-error #:decode-error-position
   #:unsupported-encoding #:unsupported-encoding-designator
   #:streaming-unsafe-encoding #:streaming-unsafe-encoding-designator
   #:invalid-leading-byte #:invalid-leading-byte-position #:invalid-leading-byte-octet
   #:invalid-continuation-byte #:invalid-continuation-byte-position
   #:invalid-continuation-byte-octet
   #:overlong-sequence #:overlong-sequence-position
   #:surrogate-code-point #:surrogate-code-point-position #:surrogate-code-point-value
   #:code-point-too-large #:code-point-too-large-position #:code-point-too-large-value
   #:truncated-sequence #:truncated-sequence-position
   #:unencodable-character #:unencodable-character-char #:unencodable-character-encoding)
  (:export #:run-tests))

(in-package #:cl-codec-kit/test)

(defun octets (&rest bytes)
  (make-array (length bytes) :element-type '(unsigned-byte 8) :initial-contents bytes))

(defun gen-scalar-value (&key (max #x10FFFF))
  "A code point generator for round-trip property tests: any Unicode scalar
value (i.e. excluding the surrogate range U+D800-U+DFFF) up to MAX. Callers
that need a BMP-only range for UCS-2/UTF-16 pass :MAX #xFFFF."
  (gen-such-that (lambda (code) (not (<= #xD800 code #xDFFF)))
                 (gen-integer :min 0 :max max)))

(defun gen-scalar-string (&key (max #x10FFFF) (min-length 0) (max-length 16))
  "A string generator built from GEN-SCALAR-VALUE code points."
  (gen-map (lambda (codes) (coerce (mapcar #'code-char codes) 'string))
           (gen-list (gen-scalar-value :max max) :min-length min-length :max-length max-length)))

(defun run-tests ()
  "Run every registered spec, signalling on any failure so ASDF's TEST-OP
fails."
  (unless (run-all :reporter :spec :timeout-ms 20000)
    (error "cl-codec-kit test suite failed"))
  (format t "~&cl-codec-kit/test: successful completion with 0 failures~%")
  t)
