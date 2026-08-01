;;;; cl-codec-kit.asd

;;; This form comes FIRST, before any defsystem. ASDF binds *package* to
;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;; `load`, an editor evaluating the buffer, flake.nix parsing :version -- the
;;; file is read in whatever package happens to be current. Saying it makes
;;; the file self-contained.
(in-package #:asdf-user)

(defsystem "cl-codec-kit"
  :description "A from-scratch, dependency-free Common Lisp codec library, babel-API-compatible"
  :long-description "cl-codec-kit decodes and encodes octet vectors and
strings across the Unicode encoding family (UTF-8, UTF-16, UTF-32, UCS-2,
each with explicit big/little-endian variants), plus ASCII and ISO-8859-1,
without delegating to SB-EXT:OCTETS-TO-STRING/STRING-TO-OCTETS or any other
implementation-provided external-format machinery. Its API is compatible in
spirit with the babel library it exists to eventually let cl-tmux stop
depending on, but is not a symbol-for-symbol port of babel's own internals.
DECODE-PREFIX -- decode as much of a buffer as forms complete characters and
hand back the incomplete trailing sequence -- generalizes a primitive
cl-tty-kit and cl-process-kit had each independently hand-rolled for UTF-8
alone. The remaining ISO-8859-2..16, Windows code pages, EBCDIC, GBK,
ISO-2022-JP, and other legacy 8-bit/CJK encodings babel supports are not yet
implemented; see docs/src/project/roadmap.md."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-codec-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-codec-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-codec-kit.git")
  :depends-on ()
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "conditions")
   (:file "registry")
   (:file "utf-8")
   (:file "utf-16")
   (:file "utf-32")
   (:file "ucs-2")
   (:file "ascii")
   (:file "iso-8859-1")
   (:file "streaming")
   (:file "api"))
  :in-order-to ((test-op (test-op "cl-codec-kit/test"))))

(defsystem "cl-codec-kit/test"
  :description "Test system for cl-codec-kit"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-codec-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-codec-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-codec-kit.git")
  :depends-on ("cl-codec-kit" "cl-weave")
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "registry-test")
   (:file "utf-8-test")
   (:file "utf-16-test")
   (:file "utf-32-test")
   (:file "ucs-2-test")
   (:file "ascii-test")
   (:file "iso-8859-1-test")
   (:file "streaming-test")
   (:file "api-test")
   (:file "oracle-test"))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (unless (funcall (symbol-function (find-symbol "RUN-TESTS" "CL-CODEC-KIT/TEST")))
               (error "cl-codec-kit test suite failed"))))
