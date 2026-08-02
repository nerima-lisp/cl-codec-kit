;;;; src/unicode.lisp
;;;;
;;;; Data and logic shared by every Unicode Transformation Format this
;;;; library implements (UTF-8, UTF-16, UTF-32, UCS-2), factored out of each
;;;; format's own file: the surrogate range and the maximum code point are
;;;; Unicode-wide invariants, not properties of any one encoding, and the
;;;; "sense a byte-order mark, else default to big-endian" dispatch that
;;;; UTF-16, UTF-32, and UCS-2's generic codecs each independently repeated
;;;; differs between them only in the BOM's own byte width and value -- data,
;;;; not logic.
(in-package #:cl-codec-kit)

(defconstant +min-surrogate+ #xD800
  "The first code point in the UTF-16 surrogate range -- invalid as a
standalone character in every encoding this library implements.")
(defconstant +max-surrogate+ #xDFFF
  "The last code point in the UTF-16 surrogate range.")
(defconstant +max-code-point+ #x10FFFF
  "The highest code point Unicode defines.")

(declaim (inline surrogate-code-point-value-p))
(defun surrogate-code-point-value-p (code-point)
  "T when CODE-POINT falls in the UTF-16 surrogate range
(+MIN-SURROGATE+..+MAX-SURROGATE+), where it can never be a standalone
character."
  (<= +min-surrogate+ code-point +max-surrogate+))

(defun %octets-start-with-p (octets start end bom)
  "T when OCTETS[START,START+(length BOM)) -- which must lie entirely within
[START,END) -- equals BOM element-for-element."
  (and (<= (+ start (length bom)) end)
       (loop for i from 0 below (length bom)
             always (= (aref octets (+ start i)) (aref bom i)))))

(defun bom-sensing-decode (octets start end bom-be bom-le be-decoder le-decoder)
  "Shared generic-decode dispatch for a BOM-sensing Unicode encoding: decode
OCTETS[START,END) with LE-DECODER past a leading BOM-LE, with BE-DECODER past
a leading BOM-BE, or with BE-DECODER over the whole range when neither BOM is
present -- Unicode's own default-to-big-endian convention for a BOM-less
buffer. BOM-BE/BOM-LE are octet vectors; BE-DECODER/LE-DECODER are decoder
functions of (octets start end), the same shape DEFINE-ENCODING registers."
  (cond
    ((%octets-start-with-p octets start end bom-be)
     (funcall be-decoder octets (+ start (length bom-be)) end))
    ((%octets-start-with-p octets start end bom-le)
     (funcall le-decoder octets (+ start (length bom-le)) end))
    (t (funcall be-decoder octets start end))))

(defun bom-sensing-encode (bom be-encoder string start end)
  "Shared generic-encode dispatch for a BOM-sensing Unicode encoding: BOM
followed by STRING[START,END) encoded with BE-ENCODER -- every generic
encoding here always writes a big-endian BOM, matching Unicode's own
recommendation for a byte-order-agnostic encoder."
  (concatenate '(vector (unsigned-byte 8)) bom (funcall be-encoder string start end)))

(defmacro define-byte-order-encoding (base-name (&key aliases-be aliases-le (resync-width 1)
                                                       (default-replacement '(code-char #x1a)))
                                       &key core-decoder core-encoder)
  "Define BASE-NAME-BE-DECODE/-ENCODE and BASE-NAME-LE-DECODE/-ENCODE as thin
wrappers around CORE-DECODER/CORE-ENCODER -- already-defined functions of
(octets/string start end byte-order) and (string start end byte-order
encoding-name) respectively, matching %U16-DECODE/-ENCODE, %U32-DECODE/-
ENCODE, and %UCS2-DECODE/-ENCODE's shape -- and register both as
CHARACTER-ENCODINGs named BASE-NAME-BE/BASE-NAME-LE via DEFINE-ENCODING.

Eliminates the six-form pattern (four wrapper DEFUNs, two DEFINE-ENCODING
calls) that UTF-16, UTF-32, and UCS-2 would otherwise each repeat verbatim,
differing only in these names and in RESYNC-WIDTH/ALIASES-*/
DEFAULT-REPLACEMENT.

DEFAULT-REPLACEMENT defaults to #x1A (SUB), matching DEFINE-ENCODING's own
default -- always passed through explicitly here (never omitted) so that
default stays live rather than silently becoming NIL, which would violate
CHARACTER-ENCODING's DEFAULT-REPLACEMENT slot's (TYPE CHARACTER) declaration
(registry.lisp)."
  (let* ((base (symbol-name base-name))
         (be-name (intern (format nil "~ABE" base)))
         (le-name (intern (format nil "~ALE" base)))
         (be-decode (intern (format nil "~A-DECODE" be-name)))
         (be-encode (intern (format nil "~A-ENCODE" be-name)))
         (le-decode (intern (format nil "~A-DECODE" le-name)))
         (le-encode (intern (format nil "~A-ENCODE" le-name)))
         (be-keyword (intern (symbol-name be-name) :keyword))
         (le-keyword (intern (symbol-name le-name) :keyword)))
    `(progn
       (defun ,be-decode (octets start end) (,core-decoder octets start end :be))
       (defun ,be-encode (string start end) (,core-encoder string start end :be ,be-keyword))
       (defun ,le-decode (octets start end) (,core-decoder octets start end :le))
       (defun ,le-encode (string start end) (,core-encoder string start end :le ,le-keyword))
       (define-encoding ,be-keyword (:aliases ,aliases-be :resync-width ,resync-width
                                      :default-replacement ,default-replacement)
         :decoder ,be-decode :encoder ,be-encode)
       (define-encoding ,le-keyword (:aliases ,aliases-le :resync-width ,resync-width
                                      :default-replacement ,default-replacement)
         :decoder ,le-decode :encoder ,le-encode))))
