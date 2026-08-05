;;;; t/package.lisp
(defpackage #:cl-codec-kit/test (:use #:cl)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   #:it #:it-each #:expect #:signals #:run-all
   #:it-property #:it-fuzz #:gen-integer #:gen-list #:gen-map #:gen-vector #:gen-member
   #:gen-such-that #:describe-each #:run-mutations #:assert-mutation-score
   #:with-soft-assertions)
  (:import-from #:cl-codec-kit
   #:octets-to-string #:string-to-octets #:string-size-in-octets #:decode-prefix
   #:lenient-decode-prefix
   #:*default-encoding* #:list-character-encodings
   #:find-character-encoding #:character-encoding-default-replacement
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
   #:unencodable-character #:unencodable-character-char #:unencodable-character-encoding
   #:unencodable-character-position)
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

(defun gen-octets (&key (min-length 0) (max-length 16))
  "A generator of arbitrary (UNSIGNED-BYTE 8) vectors, valid or not -- for
fuzzing a decoder against every possible byte sequence rather than only the
hand-picked invalid ones each FOO-test.lisp already exercises by name."
  (gen-map (lambda (bytes) (apply #'octets bytes))
           (gen-list (gen-integer :min 0 :max 255) :min-length min-length :max-length max-length)))

(defmacro it-round-trips (encoding &key (max #x10FFFF) (min-length 0) (max-length 24))
  "Register an IT-PROPERTY spec asserting that OCTETS-TO-STRING/STRING-TO-OCTETS
round-trip any string GEN-SCALAR-STRING can build within MAX/MIN-LENGTH/
MAX-LENGTH under ENCODING (an unquoted keyword). Factors out the round-trip
property test every FOO-test.lisp in this directory otherwise repeats
verbatim, differing only in these three arguments."
  `(it-property ,(format nil "round-trips any string up to U+~4,'0X, for any length" max)
       ((values (gen-scalar-string :max ,max :min-length ,min-length :max-length ,max-length)))
     (expect (octets-to-string (string-to-octets values :encoding ,encoding) :encoding ,encoding)
             :to-equal values)))

(defun run-tests (&key coverage (reporter :spec))
  "Run every registered spec, signalling on any failure so ASDF's TEST-OP
fails. COVERAGE, off by default so a plain local/CI run stays fast and
artifact-free, enables cl-weave's built-in SB-COVER integration and writes an
HTML report to coverage-report/ plus a summary to cl-codec-kit.coverage in
the current directory -- see docs/src/getting-started.md for how to read it.

REPORTER defaults to :SPEC (human-readable, what run-tests.lisp and
nix flake check both use). cl-weave also ships :JUNIT (machine-readable XML
for a CI system that ingests JUnit reports) and :GITHUB (workflow-command
annotations) among others -- pass one explicitly when invoking this function
from a context that can use it; this project's own CI runs inside a
sandboxed `nix flake check` build, where CI-provider environment variables
such as GITHUB_ACTIONS are deliberately not visible, so REPORTER cannot
usefully auto-detect that environment here."
  (unless (run-all :reporter reporter :timeout-ms 20000
                   :coverage coverage
                   :coverage-output (and coverage "cl-codec-kit.coverage")
                   :coverage-report-directory (and coverage "coverage-report/")
                   :coverage-include-pathnames
                   (and coverage
                        (list (merge-pathnames "src/"
                                                (asdf:system-source-directory "cl-codec-kit")))))
    (error "cl-codec-kit test suite failed"))
  (format t "~&cl-codec-kit/test: successful completion with 0 failures~%")
  t)
