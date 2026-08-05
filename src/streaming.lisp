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
;;;;
;;;; %DECODE-WITH-RECOVERY below is this library's one deliberately
;;;; continuation-passing function: ON-TRUNCATED is a continuation its two
;;;; callers each supply their own ending to (escape with the leftover
;;;; octets, or substitute one REPLACEMENT and fall through), rather than a
;;;; condition %DECODE-WITH-RECOVERY would have to interpret itself.
;;;; BOM-SENSING-DECODE (unicode.lisp) is the same shape one level up: which
;;;; decoder function to call is data selected by which BOM matched, not a
;;;; branch hard-coded into the dispatcher. Neither is a stylistic flourish;
;;;; both exist because the caller, not this file, is what should decide
;;;; what happens next.
;;;;
;;;; What is deliberately NOT continuation-passing is the octet-at-a-time
;;;; character loop inside every encoding's own decoder (UTF-8-DECODE and
;;;; siblings): Common Lisp does not guarantee tail-call elimination, so
;;;; threading an explicit continuation through a loop bounded only by input
;;;; length -- a stream chunk, potentially -- would trade a proven-safe
;;;; iterative LOOP for unbounded recursion depth. CPS earns its keep here
;;;; exactly where a single call has more than one sensible continuation;
;;;; forcing it onto a loop that already has exactly one next step would
;;;; only add risk.
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

(defun %decode-with-recovery (decoder octets start end resync-width replacement out
                              on-truncated on-success)
  "Decode OCTETS[START,END) with DECODER (a decoder function of (octets start
end)), writing successfully-decoded text to the string-output-stream OUT and
substituting REPLACEMENT for each invalid sequence, resuming RESYNC-WIDTH
octets past it. Every exit from this function is a call to one of its two
continuations, ON-TRUNCATED or ON-SUCCESS, never a plain RETURN -- neither
caller is left to infer 'the loop ended' from this function's own return
value, which it does not otherwise define.

A TRUNCATED-SEQUENCE is not substituted for directly here: by its own
contract (conditions.lisp), its POSITION only ever names a leading byte/unit
that runs off the true END of OCTETS, with no more data that could complete
it, so OCTETS[POSITION,END) is one malformed attempt rather than a sequence
of them -- what to do with that one attempt differs between this function's
two callers. ON-TRUNCATED (a function of one argument, the boundary position)
decides: LENIENT-DECODE-PREFIX below escapes with the boundary and its
leftover octets, since a later chunk may complete it, while %LENIENT-DECODE
(api.lisp) has no later chunk coming and substitutes REPLACEMENT once for the
whole attempt, then lets the loop run to completion. ON-SUCCESS (a function
of zero arguments) is called once OCTETS[START,END) is fully consumed
without a trailing truncation -- reached whether every sequence decoded
cleanly or the last one was substituted via REPLACEMENT, either way with
nothing left for a later chunk to complete."
  (let ((index start))
    (loop while (< index end)
          do (handler-case
                 (progn (write-string (funcall decoder octets index end) out)
                        (setf index end))
               (truncated-sequence (c)
                 (let ((position (decode-error-position c)))
                   (write-string (funcall decoder octets index position) out)
                   (funcall on-truncated position)
                   (setf index end)))
               (decode-error (c)
                 (let ((position (decode-error-position c)))
                   (write-string (funcall decoder octets index position) out)
                   (write-char replacement out)
                   (setf index (+ position resync-width))))))
    (funcall on-success)))

(defun lenient-decode-prefix (octets &key (start 0) end (encoding *default-encoding*)
                              replacement)
  "Like DECODE-PREFIX, but a genuinely invalid (as opposed to merely
truncated) sequence is replaced by REPLACEMENT and decoding continues,
matching OCTETS-TO-STRING's ERRORP NIL mode -- only a TRUNCATED-SEQUENCE at
the very end of OCTETS[START,END) is still treated as a boundary to split
at, exactly as in DECODE-PREFIX. Neither DECODE-PREFIX nor OCTETS-TO-STRING
alone provides this combination: DECODE-PREFIX signals on an invalid
sequence instead of substituting, and OCTETS-TO-STRING's lenient mode would
substitute a trailing truncated sequence instead of holding it back for the
next chunk. A caller decoding a stream in :REPLACE-style error policy needs
both at once.

REPLACEMENT NIL (the default) means ENCODING's own
CHARACTER-ENCODING-DEFAULT-REPLACEMENT (registry.lisp), exactly as in
OCTETS-TO-STRING: U+FFFD for the Unicode family, U+001A (SUB) for :ASCII and
:ISO-8859-1.

Signals STREAMING-UNSAFE-ENCODING for the same BOM-sensing designators
DECODE-PREFIX refuses, for the same reason."
  (let* ((enc (find-character-encoding encoding))
         (end (or end (length octets)))
         (replacement (or replacement (character-encoding-default-replacement enc)))
         (resync-width (character-encoding-resync-width enc))
         (decoder (character-encoding-decoder enc))
         (out (make-string-output-stream)))
    (when (character-encoding-bom-sensing-p enc)
      (error 'streaming-unsafe-encoding :designator encoding))
    (%decode-with-recovery decoder octets start end resync-width replacement out
                           (lambda (boundary)
                             (return-from lenient-decode-prefix
                               (values (get-output-stream-string out)
                                       (subseq octets boundary end))))
                           (lambda ()
                             (return-from lenient-decode-prefix
                               (values (get-output-stream-string out)
                                       (make-array 0 :element-type (array-element-type octets))))))))
