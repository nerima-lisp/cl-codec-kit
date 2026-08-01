;;;; src/conditions.lisp
;;;;
;;;; Every condition below is generated through %DEFINE-CODEC-CONDITION,
;;;; mirroring cl-concurrent-kit's %DEFINE-KIT-CONDITION: a slot's reader name
;;;; and a :REPORT method's boilerplate lambda are easy to drift between
;;;; hand-written conditions (a missing :READER, an inconsistent reader name).
;;;; The macro makes the convention the only way to spell a condition here.
(in-package #:cl-codec-kit)

(define-condition cl-codec-kit-error (error) ()
  (:documentation "Base condition for every error CL-CODEC-KIT signals. Catch
this to handle any failure from this library without naming each specific
condition."))

(defmacro %define-codec-condition (name (&rest slots) (report-control &rest report-args)
                                   &optional documentation)
  "Define NAME as a CL-CODEC-KIT-ERROR subclass with one slot per entry of
SLOTS, each (SLOT-NAME SLOT-DOCUMENTATION). A slot's initarg is the keyword of
the same name and its reader is NAME-SLOT-NAME.

REPORT-CONTROL and REPORT-ARGS become a :REPORT method's FORMAT call, with
CONDITION bound around them; REPORT-ARGS forms may refer to CONDITION freely."
  `(define-condition ,name (cl-codec-kit-error)
     ,(mapcar (lambda (slot)
                (destructuring-bind (slot-name slot-documentation) slot
                  `(,slot-name :initarg ,(intern (symbol-name slot-name) :keyword)
                               :reader ,(intern (format nil "~A-~A" name slot-name))
                               :documentation ,slot-documentation)))
              slots)
     (:report (lambda (condition stream)
                (declare (ignorable condition))
                (format stream ,report-control ,@report-args)))
     ,@(when documentation `((:documentation ,documentation)))))

(%define-codec-condition unsupported-encoding
    ((designator "The encoding designator that was not found in the registry."))
  ("Unsupported character encoding: ~S." (unsupported-encoding-designator condition))
  "Signaled by FIND-CHARACTER-ENCODING, and anything that calls it, when
DESIGNATOR names no registered encoding or alias.")

(%define-codec-condition invalid-leading-byte
    ((position "The octet index of the invalid leading byte.")
     (octet "The invalid leading byte's value."))
  ("Invalid leading byte #x~2,'0X at position ~D." (invalid-leading-byte-octet condition)
   (invalid-leading-byte-position condition))
  "Signaled while decoding a variable-width encoding when an octet that starts
a character does not match any valid leading-byte pattern for that encoding.")

(%define-codec-condition invalid-continuation-byte
    ((position "The octet index of the invalid continuation byte.")
     (octet "The invalid continuation byte's value."))
  ("Invalid continuation byte #x~2,'0X at position ~D."
   (invalid-continuation-byte-octet condition) (invalid-continuation-byte-position condition))
  "Signaled while decoding a variable-width encoding when a byte that should
continue a multi-byte sequence does not match the continuation-byte pattern.")

(%define-codec-condition overlong-sequence
    ((position "The octet index where the overlong sequence starts."))
  ("Overlong encoding of a code point starting at position ~D."
   (overlong-sequence-position condition))
  "Signaled when a multi-byte sequence encodes a code point using more octets
than its minimal encoding requires -- for example UTF-8's C0 80 for U+0000.
Overlong sequences are rejected because they let the same code point round-trip
through multiple distinct byte sequences, which is both a spec violation and a
known security-relevant ambiguity (CVE-2008-2938 and similar).")

(%define-codec-condition surrogate-code-point
    ((position "The octet index of the surrogate code point.")
     (value "The surrogate code point's value, in the range #xD800-#xDFFF."))
  ("Surrogate code point #x~4,'0X at position ~D is not a valid character."
   (surrogate-code-point-value condition) (surrogate-code-point-position condition))
  "Signaled when a decoder assembles a code point in the UTF-16 surrogate
range (U+D800-U+DFFF) from an encoding where that range is never a valid
standalone character -- UTF-8, UTF-32, and an unpaired UTF-16 surrogate.")

(%define-codec-condition code-point-too-large
    ((position "The octet index where the out-of-range code point starts.")
     (value "The assembled code point's value."))
  ("Code point #x~X at position ~D exceeds the Unicode maximum of #x10FFFF."
   (code-point-too-large-value condition) (code-point-too-large-position condition))
  "Signaled when a decoder assembles a code point above the Unicode maximum,
U+10FFFF.")

(%define-codec-condition truncated-sequence
    ((position "The octet index where the truncated sequence starts."))
  ("Truncated multi-byte sequence starting at position ~D."
   (truncated-sequence-position condition))
  "Signaled when a multi-byte sequence's leading byte or unit is valid but the
buffer ends before its continuation bytes/units do. DECODE-PREFIX catches
this specifically to split a byte buffer at a character boundary; any other
condition in this file indicates a genuine invalid sequence and propagates
instead of being treated as a decodable boundary.")

(%define-codec-condition unencodable-character
    ((char "The character that ENCODING cannot represent.")
     (encoding "The encoding designator that was asked to encode CHAR."))
  ("Character ~S is not encodable in ~S." (unencodable-character-char condition)
   (unencodable-character-encoding condition))
  "Signaled while encoding when a character's code point falls outside the
codespace ENCODING can represent -- for example any code point above U+FF in
ISO-8859-1, or above U+7F in ASCII.")
