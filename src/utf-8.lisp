;;;; src/utf-8.lisp
;;;;
;;;; A from-scratch UTF-8 codec. The decode-side validation (leading-byte
;;;; classification, continuation-byte checking, overlong-sequence rejection,
;;;; surrogate rejection, and the truncated-vs-invalid distinction) mirrors
;;;; cl-tty-kit's src/utf8.lisp, which has run as that repository's hand-rolled
;;;; decoder in production; the difference here is that TRUNCATED-SEQUENCE is
;;;; signaled as a condition (for DECODE-PREFIX in streaming.lisp to catch)
;;;; rather than pre-scanned for by the caller, and the encode side is
;;;; hand-written rather than delegated to SB-EXT:STRING-TO-OCTETS.
(in-package #:cl-codec-kit)

(declaim (inline %utf8-continuation-octet-p))
(defun %utf8-continuation-octet-p (octet)
  (<= #x80 octet #xBF))

(defparameter +utf8-multibyte-ranges+
  '((#xC2 #xDF 2 #x80) (#xE0 #xEF 3 #x800) (#xF0 #xF4 4 #x10000))
  "Data, not logic: one (LOW HIGH LENGTH MIN-CODE-POINT) entry per UTF-8
leading-byte range. LOW/HIGH bound the leading byte's own value, LENGTH is
the sequence's total octet length, and MIN-CODE-POINT is the smallest code
point a sequence of that LENGTH may legally encode -- a shorter encoding of
anything below it is an OVERLONG-SEQUENCE. %UTF8-SEQUENCE-LENGTH and
%UTF8-MIN-CODE-POINT below are the two lookups this table drives; every
leading-byte value outside these three ranges, plus every value below
#x80 (handled directly by %UTF8-DECODE-ONE before either function is
called), cannot start a valid UTF-8 sequence.")

(defun %utf8-sequence-length (leading-byte)
  "Return the total octet length (2-4) of the multi-byte sequence
LEADING-BYTE starts, or NIL if LEADING-BYTE cannot start any valid UTF-8
sequence. LEADING-BYTE < #x80 (a single-octet character) is never passed
here -- %UTF8-DECODE-ONE, the only caller, handles that case itself before
calling this function."
  (loop for (low high length) in +utf8-multibyte-ranges+
        when (<= low leading-byte high)
          return length))

(defun %utf8-min-code-point (sequence-length)
  (loop for (nil nil length min-code-point) in +utf8-multibyte-ranges+
        when (= length sequence-length)
          return min-code-point))

(defun %utf8-validate-continuation-bytes (octets index length end)
  "Signal INVALID-CONTINUATION-BYTE or TRUNCATED-SEQUENCE if the LENGTH-octet
sequence starting at INDEX does not have LENGTH-1 valid continuation bytes
available before END. An invalid continuation byte is never a truncation, no
matter how few bytes remain -- check every available one first.

POSITION is INDEX (the sequence's own leading byte), not the offending
continuation byte's own offset: every position-bearing condition in this
library marks where the failing character *starts*, which is the invariant
DECODE-PREFIX (streaming.lisp) and %LENIENT-DECODE (api.lisp) both rely on
to redecode OCTETS[attempt-start,POSITION) as a guaranteed-clean prefix.
OCTET still names the specific bad byte for diagnostics."
  (let ((available (- end index 1)))
    (loop for offset from 1 below (min length (1+ available))
          for byte = (aref octets (+ index offset))
          unless (%utf8-continuation-octet-p byte)
            do (error 'invalid-continuation-byte :position index :octet byte))
    (when (< available (1- length))
      (error 'truncated-sequence :position index))))

(defun %utf8-assemble-code-point (octets index length first)
  "Combine the low bits of FIRST (the leading byte at INDEX) with the low six
bits of each of the LENGTH-1 continuation bytes following it into one code
point, per UTF-8's bit layout for a sequence of LENGTH octets."
  (case length
    (2 (logior (ash (logand first #x1F) 6)
               (logand (aref octets (1+ index)) #x3F)))
    (3 (logior (ash (logand first #x0F) 12)
               (ash (logand (aref octets (1+ index)) #x3F) 6)
               (logand (aref octets (+ index 2)) #x3F)))
    (4 (logior (ash (logand first #x07) 18)
               (ash (logand (aref octets (1+ index)) #x3F) 12)
               (ash (logand (aref octets (+ index 2)) #x3F) 6)
               (logand (aref octets (+ index 3)) #x3F)))))

(defun %utf8-validate-code-point (code-point index length)
  "Signal OVERLONG-SEQUENCE, SURROGATE-CODE-POINT, or CODE-POINT-TOO-LARGE if
CODE-POINT, assembled from the LENGTH-octet sequence starting at INDEX, is
not a value UTF-8 may legally encode as that many octets."
  (when (< code-point (%utf8-min-code-point length))
    (error 'overlong-sequence :position index))
  (when (surrogate-code-point-value-p code-point)
    (error 'surrogate-code-point :position index :value code-point))
  (when (> code-point +max-code-point+)
    (error 'code-point-too-large :position index :value code-point)))

(defun %utf8-decode-one (octets index end)
  "Decode one character from OCTETS starting at INDEX, never reading at or
past END. Returns (values character next-index). Classifies the leading
byte, validates the sequence's continuation bytes are present and
well-formed, assembles the code point, then validates that code point --
each its own step below, since each can fail for a different reason and
signal a different condition."
  (let ((first (aref octets index)))
    (if (< first #x80)
        (values (code-char first) (1+ index))
        (let ((length (%utf8-sequence-length first)))
          (unless length
            (error 'invalid-leading-byte :position index :octet first))
          (%utf8-validate-continuation-bytes octets index length end)
          (let ((code-point (%utf8-assemble-code-point octets index length first)))
            (%utf8-validate-code-point code-point index length)
            (values (code-char code-point) (+ index length)))))))

(defun utf-8-decode (octets start end)
  (with-output-to-string (out)
    (loop with index = start
          while (< index end)
          do (multiple-value-bind (char next) (%utf8-decode-one octets index end)
               (write-char char out)
               (setf index next)))))

(defun %utf8-encoded-length (code-point char position)
  "Return the octet length CODE-POINT needs in UTF-8, or signal
UNENCODABLE-CHARACTER for a surrogate half or an out-of-range code point."
  (cond
    ((< code-point #x80) 1)
    ((< code-point #x800) 2)
    ((surrogate-code-point-value-p code-point)
     (error 'unencodable-character :char char :encoding :utf-8 :position position))
    ((< code-point #x10000) 3)
    ((<= code-point +max-code-point+) 4)
    (t (error 'unencodable-character :char char :encoding :utf-8 :position position))))

(defun utf-8-encode (string start end)
  (let ((size 0))
    (loop for i from start below end
          do (incf size (%utf8-encoded-length (char-code (char string i)) (char string i) i)))
    (let ((result (make-array size :element-type '(unsigned-byte 8)))
          (offset 0))
      (loop for i from start below end
            for code = (char-code (char string i))
            do (cond
                 ((< code #x80)
                  (setf (aref result offset) code)
                  (incf offset))
                 ((< code #x800)
                  (setf (aref result offset) (logior #xC0 (ash code -6))
                        (aref result (1+ offset)) (logior #x80 (logand code #x3F)))
                  (incf offset 2))
                 ((< code #x10000)
                  (setf (aref result offset) (logior #xE0 (ash code -12))
                        (aref result (1+ offset)) (logior #x80 (logand (ash code -6) #x3F))
                        (aref result (+ offset 2)) (logior #x80 (logand code #x3F)))
                  (incf offset 3))
                 (t
                  (setf (aref result offset) (logior #xF0 (ash code -18))
                        (aref result (1+ offset)) (logior #x80 (logand (ash code -12) #x3F))
                        (aref result (+ offset 2)) (logior #x80 (logand (ash code -6) #x3F))
                        (aref result (+ offset 3)) (logior #x80 (logand code #x3F)))
                  (incf offset 4))))
      result)))

(define-encoding :utf-8 (:default-replacement #\REPLACEMENT_CHARACTER)
  :decoder utf-8-decode
  :encoder utf-8-encode)
