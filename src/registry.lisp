(in-package #:cl-codec-kit)

(defstruct (character-encoding (:constructor %make-character-encoding)
                                (:predicate %character-encoding-p)
                                (:copier nil))
  (name nil :type keyword :read-only t)
  (decoder nil :type function :read-only t)
  (encoder nil :type function :read-only t)
  (resync-width 1 :type (integer 1) :read-only t)
  (bom-sensing-p nil :type boolean :read-only t)
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
