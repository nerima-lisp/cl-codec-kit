;;;; src/api.lisp
;;;;
;;;; The public entry points. Every function here dispatches through the
;;;; registry (registry.lisp) via FIND-CHARACTER-ENCODING rather than calling
;;;; a specific encoding's decoder/encoder directly, so adding a new encoding
;;;; file never touches this one.
(in-package #:cl-codec-kit)

(defun %lenient-decode (encoding-struct octets start end replacement)
  "Decode OCTETS[START,END) with ENCODING-STRUCT, substituting REPLACEMENT
for each invalid or truncated sequence instead of signaling, via
%DECODE-WITH-RECOVERY (streaming.lisp). Every decoder in this library only
ever signals a DECODE-ERROR (conditions.lisp) at the start of the character
it is currently failing on, so OCTETS[INDEX,POSITION) is always exactly what
the current attempt had already, successfully, decoded before hitting it --
redecoding that prefix from scratch is guaranteed to succeed, never
re-signal, and never desynchronize a fixed-width encoding's remaining code
units, because resuming from POSITION by RESYNC-WIDTH (not by one octet)
always lands back on a unit boundary.

A TRUNCATED-SEQUENCE gets exactly one REPLACEMENT for the whole remaining
OCTETS[POSITION,END), never a RESYNC-WIDTH-at-a-time resumption into it:
unlike LENIENT-DECODE-PREFIX's caller (streaming.lisp), this function's
caller has no later chunk that could complete a truncated sequence, so
treating its remaining bytes as further, spurious ones would be wrong.

ENCODING-STRUCT must not be BOM-sensing (see CHARACTER-ENCODING-BOM-SENSING-P
in registry.lisp); OCTETS-TO-STRING checks this before calling here."
  (let ((resync-width (character-encoding-resync-width encoding-struct))
        (decoder (character-encoding-decoder encoding-struct)))
    (with-output-to-string (out)
      (%decode-with-recovery decoder octets start end resync-width replacement out
                             (lambda (position)
                               (declare (ignore position))
                               (write-char replacement out))
                             (lambda ())))))

(defun octets-to-string (octets &key (start 0) end (encoding *default-encoding*)
                                (errorp t) replacement)
  "Decode OCTETS[START,END) (default the whole vector) as ENCODING into a
string. When ERRORP is true (the default), an invalid or truncated sequence
signals the corresponding condition from conditions.lisp. When ERRORP is
NIL, each invalid or truncated sequence is instead replaced by REPLACEMENT
and decoding continues.

REPLACEMENT NIL (the default) means ENCODING's own
CHARACTER-ENCODING-DEFAULT-REPLACEMENT (registry.lisp): U+FFFD for every
Unicode-family encoding registered here, U+001A (SUB) for :ASCII and
:ISO-8859-1. That split is babel's, taken from where babel actually makes it
-- the substitution code point its codecs pass to DECODING-ERROR -- and not
from its ENC-DEFAULT-REPLACEMENT slot, which no babel code path reads.

A single ERRORP T call is safe for every registered encoding, including the
generic, BOM-sensing :UTF-16/:UTF-32/:UCS-2 (it decodes OCTETS once, so a
byte-order mark is only ever sensed at OCTETS' own start). ERRORP NIL,
though, signals STREAMING-UNSAFE-ENCODING for those three designators, for
the same reason DECODE-PREFIX (streaming.lisp) does: recovering from an
error resumes decoding at an interior offset, where a BOM-sensing decoder
would wrongly re-check for a byte-order mark."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length octets)))
         (replacement (or replacement (character-encoding-default-replacement enc))))
    (if errorp
        (funcall (character-encoding-decoder enc) octets start end)
        (progn
          (when (character-encoding-bom-sensing-p enc)
            (error 'streaming-unsafe-encoding :designator encoding))
          (%lenient-decode enc octets start end replacement)))))

(defun %lenient-encode (encoding-struct string start end replacement)
  "Encode STRING[START,END) with ENCODING-STRUCT, substituting REPLACEMENT's
own encoding for each character ENCODING-STRUCT cannot represent instead of
signaling. Unlike %LENIENT-DECODE, resuming past a bad character never needs
a resync width: one CL character is always exactly one STRING index, so
UNENCODABLE-CHARACTER's POSITION (conditions.lisp) already names the next
character to try. If REPLACEMENT itself is not representable in
ENCODING-STRUCT, UNENCODABLE-CHARACTER propagates uncaught rather than
looping."
  (let ((encoder (character-encoding-encoder encoding-struct)))
    (let ((chunks '())
          (index start))
      (loop while (< index end)
            do (handler-case
                   (progn (push (funcall encoder string index end) chunks)
                          (setf index end))
                 (unencodable-character (c)
                   (let ((position (unencodable-character-position c)))
                     (push (funcall encoder string index position) chunks)
                     (push (funcall encoder (string replacement) 0 1) chunks)
                     (setf index (1+ position))))))
      (apply #'concatenate '(vector (unsigned-byte 8)) (nreverse chunks)))))

(defun string-to-octets (string &key (start 0) end (encoding *default-encoding*)
                                (errorp t) replacement)
  "Encode STRING[START,END) (default the whole string) as ENCODING into a
fresh (UNSIGNED-BYTE 8) vector. When ERRORP is true (the default), a
character ENCODING cannot represent signals UNENCODABLE-CHARACTER. When
ERRORP is NIL, each unencodable character is instead replaced by
REPLACEMENT's own encoding and encoding continues.

REPLACEMENT NIL (the default) means ENCODING's own
CHARACTER-ENCODING-DEFAULT-REPLACEMENT, exactly as in OCTETS-TO-STRING:
U+FFFD for the Unicode family, U+001A (SUB) for :ASCII and :ISO-8859-1.
Every encoding's default is representable in that encoding, so the default
never trips the propagate-rather-than-loop case in %LENIENT-ENCODE; an
explicit REPLACEMENT still can."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length string)))
         (replacement (or replacement (character-encoding-default-replacement enc))))
    (if errorp
        (funcall (character-encoding-encoder enc) string start end)
        (%lenient-encode enc string start end replacement))))

(defun string-size-in-octets (string &key (start 0) end (encoding *default-encoding*))
  "Return how many octets STRING-TO-OCTETS would produce for the same
arguments. Calls STRING-TO-OCTETS and discards the result rather than
measuring without allocating; exists for API parity with babel's own
STRING-SIZE-IN-OCTETS, not as a faster alternative to encoding."
  (length (string-to-octets string :start start :end end :encoding encoding)))
