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
;;;; POSITION slot naming where that final, incomplete character starts.
(in-package #:cl-codec-kit)

(defun %condition-position (condition)
  "Extract a decode condition's POSITION slot generically, without depending
on any one condition type's specific reader name -- every position-bearing
condition in conditions.lisp names its slot POSITION."
  (and (typep condition 'cl-codec-kit-error)
       (slot-exists-p condition 'position)
       (slot-boundp condition 'position)
       (slot-value condition 'position)))

(defun decode-prefix (octets &key (start 0) end (encoding *default-encoding*))
  "Decode as much of OCTETS[START,END) as forms complete characters. Returns
two values: the decoded string, and a fresh octet vector holding whatever
incomplete trailing sequence remains (empty when OCTETS ends on a character
boundary). Any invalid -- as opposed to merely truncated -- byte sequence
still signals normally; only a TRUNCATED-SEQUENCE at the very end of the
range is treated as a boundary to split at rather than an error."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length octets))))
    (handler-case
        (values (funcall (character-encoding-decoder enc) octets start end)
                (make-array 0 :element-type (array-element-type octets)))
      (truncated-sequence (c)
        (let ((boundary (%condition-position c)))
          (values (funcall (character-encoding-decoder enc) octets start boundary)
                  (subseq octets boundary end)))))))
