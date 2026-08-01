;;;; src/api.lisp
;;;;
;;;; The public entry points. Every function here dispatches through the
;;;; registry (registry.lisp) via FIND-CHARACTER-ENCODING rather than calling
;;;; a specific encoding's decoder/encoder directly, so adding a new encoding
;;;; file never touches this one.
(in-package #:cl-codec-kit)

(defun %lenient-decode (encoding-struct octets start end replacement)
  "Decode OCTETS[START,END) with ENCODING-STRUCT, substituting REPLACEMENT
for each invalid or truncated sequence instead of signaling. Reuses whatever
prefix each attempt decoded before its error, via the same POSITION-slot
contract DECODE-PREFIX relies on, then resumes one octet past the failure --
this is what lets one implementation cover every encoding's own notion of
'one bad sequence' without this function knowing any encoding's byte shapes."
  (with-output-to-string (out)
    (let ((index start))
      (loop while (< index end)
            do (handler-case
                   (progn
                     (write-string (funcall (character-encoding-decoder encoding-struct)
                                             octets index end)
                                   out)
                     (setf index end))
                 (cl-codec-kit-error (c)
                   (let ((position (%condition-position c)))
                     (if position
                         (progn
                           (write-string (funcall (character-encoding-decoder encoding-struct)
                                                   octets index position)
                                         out)
                           (write-char replacement out)
                           (setf index (1+ position)))
                         (progn (write-char replacement out) (setf index end))))))))))

(defun octets-to-string (octets &key (start 0) end (encoding *default-encoding*)
                                (errorp t) (replacement (code-char #x1a)))
  "Decode OCTETS[START,END) (default the whole vector) as ENCODING into a
string. When ERRORP is true (the default), an invalid or truncated sequence
signals the corresponding condition from conditions.lisp. When ERRORP is
NIL, each invalid or truncated sequence is instead replaced by REPLACEMENT
and decoding continues -- REPLACEMENT defaults to #x1A (SUB), matching
babel's own ENC-DEFAULT-REPLACEMENT default rather than U+FFFD."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length octets))))
    (if errorp
        (funcall (character-encoding-decoder enc) octets start end)
        (%lenient-decode enc octets start end replacement))))

(defun string-to-octets (string &key (start 0) end (encoding *default-encoding*))
  "Encode STRING[START,END) (default the whole string) as ENCODING into a
fresh (UNSIGNED-BYTE 8) vector. Always signals UNENCODABLE-CHARACTER on a
character ENCODING cannot represent; unlike OCTETS-TO-STRING there is no
lenient mode here, since none of this library's callers need one on encode."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length string))))
    (funcall (character-encoding-encoder enc) string start end)))

(defun string-size-in-octets (string &key (start 0) end (encoding *default-encoding*))
  "Return how many octets STRING-TO-OCTETS would produce for the same
arguments, without retaining the encoded vector."
  (length (string-to-octets string :start start :end end :encoding encoding)))
