;;;; src/streaming.lisp
;;;;
;;;; DECODE-PREFIX is the primitive this library exists to consolidate: both
;;;; cl-tty-kit's %UTF8-DECODE-PREFIX and cl-process-kit's
;;;; %DECODE-COMPLETE-PREFIX independently reinvented "decode as much of a
;;;; byte buffer as forms complete characters, and hand back whatever
;;;; incomplete trailing sequence remains" -- a shape babel itself never
;;;; needed, since babel only ever decodes a complete, static buffer.
;;;;
;;;; It works across every registered encoding, generic-width or not, because
;;;; it relies on exactly one contract every decoder in this library upholds:
;;;; when a character's leading byte/unit is valid but the buffer ends before
;;;; its remaining octets do, the decoder signals TRUNCATED-SEQUENCE with a
;;;; POSITION naming where that final, incomplete character starts -- a
;;;; contract DECODE-ERROR (conditions.lisp) makes structural, not just
;;;; conventional.
(in-package #:cl-codec-kit)

(defun decode-prefix (octets &key (start 0) end (encoding *default-encoding*))
  "Decode as much of OCTETS[START,END) as forms complete characters. Returns
two values: the decoded string, and a fresh octet vector holding whatever
incomplete trailing sequence remains (empty when OCTETS ends on a character
boundary). Any invalid -- as opposed to merely truncated -- byte sequence
still signals normally; only a TRUNCATED-SEQUENCE at the very end of the
range is treated as a boundary to split at rather than an error.

Signals STREAMING-UNSAFE-ENCODING for :UTF-16, :UTF-32, and :UCS-2 (the
generic, byte-order-sensing designators) rather than ever attempting them:
this function exists to be called repeatedly across a stream's chunks, and a
byte-order mark is only meaningful at that stream's true start -- there is
no way for a single, stateless call to know whether OCTETS is the first
chunk or a later one. Use an explicit :UTF-16BE/:UTF-16LE/:UTF-32BE/etc.
designator instead."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length octets))))
    (when (character-encoding-bom-sensing-p enc)
      (error 'streaming-unsafe-encoding :designator encoding))
    (handler-case
        (values (funcall (character-encoding-decoder enc) octets start end)
                (make-array 0 :element-type (array-element-type octets)))
      (truncated-sequence (c)
        (let ((boundary (decode-error-position c)))
          (values (funcall (character-encoding-decoder enc) octets start boundary)
                  (subseq octets boundary end)))))))
