;;;; src/api.lisp
;;;;
;;;; The public entry points. Every function here dispatches through the
;;;; registry (registry.lisp) via FIND-CHARACTER-ENCODING rather than calling
;;;; a specific encoding's decoder/encoder directly, so adding a new encoding
;;;; file never touches this one.
(in-package #:cl-codec-kit)

(defun %lenient-decode (encoding-struct octets start end replacement)
  "Decode OCTETS[START,END) with ENCODING-STRUCT, substituting REPLACEMENT
for each invalid or truncated sequence instead of signaling. Every decoder in
this library only ever signals a DECODE-ERROR (conditions.lisp) at the start
of the character it is currently failing on, so OCTETS[INDEX,POSITION) is
always exactly what the current attempt had already, successfully, decoded
before hitting it -- redecoding that prefix from scratch is guaranteed to
succeed, never re-signal, and never desynchronize a fixed-width encoding's
remaining code units, because resuming from POSITION by RESYNC-WIDTH (not by
one octet) always lands back on a unit boundary.

ENCODING-STRUCT must not be BOM-sensing (see CHARACTER-ENCODING-BOM-SENSING-P
in registry.lisp); OCTETS-TO-STRING checks this before calling here."
  (let ((resync-width (character-encoding-resync-width encoding-struct)))
    (with-output-to-string (out)
      (let ((index start))
        (loop while (< index end)
              do (handler-case
                     (progn
                       (write-string (funcall (character-encoding-decoder encoding-struct)
                                               octets index end)
                                     out)
                       (setf index end))
                   (decode-error (c)
                     (let ((position (decode-error-position c)))
                       (write-string (funcall (character-encoding-decoder encoding-struct)
                                               octets index position)
                                     out)
                       (write-char replacement out)
                       (setf index (+ position resync-width))))))))))

(defun octets-to-string (octets &key (start 0) end (encoding *default-encoding*)
                                (errorp t) (replacement (code-char #x1a)))
  "Decode OCTETS[START,END) (default the whole vector) as ENCODING into a
string. When ERRORP is true (the default), an invalid or truncated sequence
signals the corresponding condition from conditions.lisp. When ERRORP is
NIL, each invalid or truncated sequence is instead replaced by REPLACEMENT
and decoding continues -- REPLACEMENT defaults to #x1A (SUB), matching
babel's own ENC-DEFAULT-REPLACEMENT default rather than U+FFFD.

A single ERRORP T call is safe for every registered encoding, including the
generic, BOM-sensing :UTF-16/:UTF-32/:UCS-2 (it decodes OCTETS once, so a
byte-order mark is only ever sensed at OCTETS' own start). ERRORP NIL,
though, signals STREAMING-UNSAFE-ENCODING for those three designators, for
the same reason DECODE-PREFIX (streaming.lisp) does: recovering from an
error resumes decoding at an interior offset, where a BOM-sensing decoder
would wrongly re-check for a byte-order mark."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length octets))))
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
                                (errorp t) (replacement (code-char #x1a)))
  "Encode STRING[START,END) (default the whole string) as ENCODING into a
fresh (UNSIGNED-BYTE 8) vector. When ERRORP is true (the default), a
character ENCODING cannot represent signals UNENCODABLE-CHARACTER. When
ERRORP is NIL, each unencodable character is instead replaced by
REPLACEMENT's own encoding and encoding continues -- REPLACEMENT defaults to
#x1A (SUB), representable in every encoding this library registers, matching
OCTETS-TO-STRING's own default and babel's ENC-DEFAULT-REPLACEMENT."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length string))))
    (if errorp
        (funcall (character-encoding-encoder enc) string start end)
        (%lenient-encode enc string start end replacement))))

(defun string-size-in-octets (string &key (start 0) end (encoding *default-encoding*))
  "Return how many octets STRING-TO-OCTETS would produce for the same
arguments. Calls STRING-TO-OCTETS and discards the result rather than
measuring without allocating; exists for API parity with babel's own
STRING-SIZE-IN-OCTETS, not as a faster alternative to encoding."
  (length (string-to-octets string :start start :end end :encoding encoding)))
