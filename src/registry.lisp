;;;; src/registry.lisp
;;;;
;;;; The encoding registry is the one seam every encoding file and every
;;;; public API function goes through. An encoding is a DECODER function of
;;;; (octets start end) -> string that decodes exactly that half-open range,
;;;; and an ENCODER function of (string start end) -> octet-vector. Neither
;;;; function ever sees the other encodings; DECODE-PREFIX (streaming.lisp)
;;;; and the public API (api.lisp) are the only code that dispatches through
;;;; the registry instead of calling a specific encoding's functions directly.
;;;;
;;;; A DECODER signals TRUNCATED-SEQUENCE (conditions.lisp) when the octet
;;;; range ends mid-character on an otherwise-valid leading byte/unit, and
;;;; the condition's POSITION slot names where that final character starts.
;;;; This is the only contract DECODE-PREFIX relies on to be encoding-generic.
(in-package #:cl-codec-kit)

(defstruct (character-encoding (:constructor %make-character-encoding)
                                (:predicate %character-encoding-p)
                                (:copier nil))
  (name nil :type keyword :read-only t)
  (decoder nil :type function :read-only t)
  (encoder nil :type function :read-only t)
  ;; The octet width of one code unit: 1 for UTF-8/ASCII/ISO-8859-1 (which
  ;; also use it, trivially, as their own resync step), 2 for UTF-16/UCS-2,
  ;; 4 for UTF-32. %LENIENT-DECODE (api.lisp) advances by exactly this many
  ;; octets past a decode error's POSITION before retrying, since every
  ;; decoder here only ever signals at a unit-aligned offset -- advancing by
  ;; a single octet instead would desynchronize a fixed-width encoding's
  ;; remaining code units for the rest of the buffer.
  (resync-width 1 :type (integer 1) :read-only t)
  ;; T for the generic, byte-order-sensing encodings (:UTF-16, :UTF-32,
  ;; :UCS-2): their decoder re-sniffs a BOM at whatever octet index it is
  ;; given, which is only correct for a single, complete, buffer-at-once
  ;; decode. DECODE-PREFIX and %LENIENT-DECODE (api.lisp) both call a
  ;; decoder more than once, at internal resume offsets that a real BOM
  ;; could coincidentally appear at -- silently flipping the assumed byte
  ;; order for an unrelated reason, or (UTF-32) assembling a bogus code
  ;; point large enough to signal CODE-POINT-TOO-LARGE somewhere neither
  ;; function's HANDLER-CASE is written to catch. Both refuse a
  ;; BOM-SENSING-P encoding up front instead.
  (bom-sensing-p nil :type boolean :read-only t)
  ;; The character OCTETS-TO-STRING, STRING-TO-OCTETS (api.lisp), and
  ;; LENIENT-DECODE-PREFIX (streaming.lisp) substitute when the caller asks
  ;; for lenient behavior without naming a :REPLACEMENT of its own.
  ;;
  ;; This is per-encoding because babel's own substitution is per-encoding.
  ;; babel's Unicode codecs pass +REPL+ (#xFFFD) to every DECODING-ERROR and
  ;; ENCODING-ERROR call they make (enc-unicode.lisp: the constant at :33,
  ;; used at :187, :193, :629, :633, :757, :777), while its single-octet
  ;; codecs -- :ASCII and :ISO-8859-1 among them -- are built by
  ;; DEFINE-UNIBYTE-DECODER/-ENCODER, whose HANDLE-ERROR passes
  ;; +DEFAULT-SUBSTITUTION-CODE-POINT+ (#x1A, SUB) instead
  ;; (encodings.lisp:370, :405, :430). babel's own ENC-DEFAULT-REPLACEMENT
  ;; slot reads like it decides this, but no babel code path ever consults
  ;; it -- it is exported metadata and nothing more.
  ;;
  ;; #x1A is also the only value that can work for :ASCII and :ISO-8859-1 in
  ;; the encode direction: U+FFFD is representable in neither, so a U+FFFD
  ;; default would make STRING-TO-OCTETS :ERRORP NIL propagate
  ;; UNENCODABLE-CHARACTER for the replacement itself (see %LENIENT-ENCODE).
  (default-replacement (code-char #x1a) :type character :read-only t))

(defvar *encodings* (make-hash-table :test 'eq)
  "Maps every registered encoding keyword, including aliases, to its
CHARACTER-ENCODING. Populated by DEFINE-ENCODING; never mutated elsewhere.")

(defvar *default-encoding* :utf-8
  "The encoding OCTETS-TO-STRING, STRING-TO-OCTETS, STRING-SIZE-IN-OCTETS, and
DECODE-PREFIX use when their :ENCODING argument is not supplied.")

(defmacro define-encoding (name (&key aliases (resync-width 1) bom-sensing-p
                                       (default-replacement '(code-char #x1a)))
                           &key decoder encoder)
  "Register NAME (and each of ALIASES) as a CHARACTER-ENCODING backed by
DECODER and ENCODER, both already-defined function names, RESYNC-WIDTH,
BOM-SENSING-P, and DEFAULT-REPLACEMENT (see the CHARACTER-ENCODING slots of
the same names; all three default to values correct for a byte-oriented,
fixed-order, non-Unicode encoding).

DEFAULT-REPLACEMENT defaults to #x1A (SUB) rather than U+FFFD deliberately:
that is the fallback babel's single-octet codecs take, and the encodings
still unimplemented here (the ISO-8859-2..16, Windows code page, EBCDIC, and
KOI8 families -- see docs/src/project/roadmap.md) are all of that kind. Only
a Unicode-family encoding, which can represent U+FFFD, overrides it.

Re-registering an existing NAME replaces it -- loading this file's
definitions in :SERIAL order is what makes each encoding file independent of
load order among the others.

NAME is bound once, via the once-only idiom, since it is spliced into the
expansion three times: a form with side effects (unlikely for a keyword
literal in practice, but not ruled out by this macro's contract) would
otherwise run three times instead of once."
  (let ((name-var (gensym "NAME")) (encoding-var (gensym "ENCODING")))
    `(let* ((,name-var ,name)
            (,encoding-var (%make-character-encoding :name ,name-var :decoder #',decoder
                                                      :encoder #',encoder
                                                      :resync-width ,resync-width
                                                      :bom-sensing-p ,bom-sensing-p
                                                      :default-replacement ,default-replacement)))
       (dolist (designator (cons ,name-var ',aliases))
         (setf (gethash designator *encodings*) ,encoding-var))
       ,name-var)))

(defun find-character-encoding (designator)
  "Return the CHARACTER-ENCODING registered under DESIGNATOR (a keyword naming
an encoding or one of its aliases), or signal UNSUPPORTED-ENCODING."
  (or (gethash designator *encodings*)
      (error 'unsupported-encoding :designator designator)))

(defun list-character-encodings ()
  "Return a list of every canonical encoding name currently registered.
Aliases are omitted; each entry is exactly one CHARACTER-ENCODING's NAME."
  (let ((seen (make-hash-table :test 'eq))
        (result '()))
    (maphash (lambda (designator encoding)
               (declare (ignore designator))
               (unless (gethash encoding seen)
                 (setf (gethash encoding seen) t)
                 (push (character-encoding-name encoding) result)))
             *encodings*)
    (nreverse result)))
