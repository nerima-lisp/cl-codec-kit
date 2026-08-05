;;;; t/streaming-test.lisp
;;;;
;;;; DECODE-PREFIX is this library's answer to what cl-tty-kit's
;;;; %UTF8-DECODE-PREFIX and cl-process-kit's %DECODE-COMPLETE-PREFIX each
;;;; hand-rolled independently -- these tests exercise it across more than
;;;; one encoding to confirm it is genuinely encoding-generic, not merely
;;;; UTF-8-shaped.
(in-package #:cl-codec-kit/test)

(describe
  "DECODE-PREFIX"
  (it "decodes the whole buffer with an empty leftover when it ends on a boundary"
    ;; WITH-SOFT-ASSERTIONS: these three EXPECTs are independent claims about
    ;; the same call: a failure on the first (wrong string) says nothing
    ;; about whether the other two (leftover length, leftover element type)
    ;; also fail, so stopping at the first would hide that diagnostic.
    (with-soft-assertions
      (let ((octets (string-to-octets "café" :encoding :utf-8)))
        (multiple-value-bind (string leftover) (decode-prefix octets :encoding :utf-8)
          (expect string :to-equal "café")
          (expect (length leftover) :to-be 0)
          (expect (array-element-type leftover) :to-equal (array-element-type octets))))))

  (it "splits UTF-8 at the last complete character, leaving a truncated tail"
    (with-soft-assertions
      (let* ((full (string-to-octets "café" :encoding :utf-8))
             (end (1- (length full))))
        (multiple-value-bind (string leftover) (decode-prefix full :end end :encoding :utf-8)
          (expect string :to-equal "caf")
          (expect (length leftover) :to-be 1)
          ;; LEFTOVER is FULL[END-(LENGTH LEFTOVER),END) -- the truncated
          ;; character's own leading byte(s), not simply FULL's last octet
          ;; (which would be wrong whenever END is not the buffer's own
          ;; length, as it isn't here).
          (expect leftover :to-equalp (subseq full (- end (length leftover)) end))))))

  (it "splits UTF-16 at a character boundary that falls mid-surrogate-pair"
    (let* ((full (string-to-octets "a😀" :encoding :utf-16be))
           (end (1- (length full))))
      (multiple-value-bind (string leftover) (decode-prefix full :end end :encoding :utf-16be)
        (expect string :to-equal "a")
        (expect (length leftover) :to-be 3)
        (expect leftover :to-equalp (subseq full (- end (length leftover)) end)))))

  (it "propagates a genuinely invalid sequence rather than treating it as a boundary"
    (signals invalid-leading-byte
        (decode-prefix (octets #x41 #x80) :encoding :utf-8)))

  (it "signals STREAMING-UNSAFE-ENCODING for the generic, BOM-sensing designators"
    ;; A repeated DECODE-PREFIX call re-senses a BOM at whatever offset it
    ;; resumes at, which is only correct at a stream's true start -- see
    ;; registry.lisp's CHARACTER-ENCODING-BOM-SENSING-P.
    (dolist (encoding '(:utf-16 :utf-32 :ucs-2))
      (handler-case
          (progn (decode-prefix (octets #x00) :encoding encoding)
                 (error "expected STREAMING-UNSAFE-ENCODING for ~S" encoding))
        (streaming-unsafe-encoding (c)
          (expect (streaming-unsafe-encoding-designator c) :to-be encoding))))
    ;; The explicit BE/LE designators are unaffected.
    (multiple-value-bind (string leftover) (decode-prefix (octets #x00 #x41) :encoding :utf-16be)
      (expect string :to-equal "A")
      (expect (length leftover) :to-be 0)))

  (it "reassembles to the original string when the leftover is fed back in with more data"
    (let* ((full (string-to-octets "hello 日本語 world" :encoding :utf-8)))
      (loop for cut from 0 to (length full)
            do (multiple-value-bind (string leftover) (decode-prefix full :end cut :encoding :utf-8)
                 (expect (concatenate 'string string
                                      (octets-to-string (concatenate '(vector (unsigned-byte 8))
                                                                     leftover (subseq full cut))
                                                        :encoding :utf-8))
                         :to-equal "hello 日本語 world"))))))

(describe
  "LENIENT-DECODE-PREFIX"
  (it "decodes the whole buffer with an empty leftover when it ends on a boundary"
    (let ((octets (string-to-octets "café" :encoding :utf-8)))
      (multiple-value-bind (string leftover) (lenient-decode-prefix octets :encoding :utf-8)
        (expect string :to-equal "café")
        (expect (length leftover) :to-be 0))))

  (it "holds back a trailing truncated sequence instead of replacing it, like DECODE-PREFIX"
    (let* ((full (string-to-octets "café" :encoding :utf-8))
           (end (1- (length full))))
      (multiple-value-bind (string leftover) (lenient-decode-prefix full :end end :encoding :utf-8)
        (expect string :to-equal "caf")
        (expect leftover :to-equalp (subseq full (- end (length leftover)) end)))))

  (it "replaces a genuinely invalid sequence and keeps decoding past it, unlike DECODE-PREFIX"
    (multiple-value-bind (string leftover)
        (lenient-decode-prefix (octets #x61 #x80 #x62) :encoding :utf-8)
      (expect string :to-equal (format nil "a~Cb" #\REPLACEMENT_CHARACTER))
      (expect (length leftover) :to-be 0)))

  (it "honors a custom :REPLACEMENT character"
    (multiple-value-bind (string leftover)
        (lenient-decode-prefix (octets #x61 #x80 #x62) :encoding :utf-8 :replacement #\?)
      (expect string :to-equal "a?b")
      (expect (length leftover) :to-be 0)))

  (it "takes its default REPLACEMENT from the encoding, not from a single constant"
    ;; The same call shape under two encodings must substitute two different
    ;; characters -- U+FFFD under UTF-8, #x1A (SUB) under ASCII, which cannot
    ;; represent U+FFFD at all. OCTETS-TO-STRING's own version of this is in
    ;; api-test.lisp; this pins that LENIENT-DECODE-PREFIX resolves the
    ;; default the same way rather than keeping a constant of its own.
    (expect (lenient-decode-prefix (octets #x61 #x80 #x62) :encoding :utf-8)
            :to-equal (format nil "a~Cb" #\REPLACEMENT_CHARACTER))
    (expect (lenient-decode-prefix (octets #x61 #x80 #x62) :encoding :ascii)
            :to-equal (format nil "a~Cb" (code-char #x1a))))

  (it "resumes by RESYNC-WIDTH octets, not one, after a mid-buffer error in a wide encoding"
    ;; An unpaired low surrogate as a lone UTF-16BE code unit is invalid, not
    ;; truncated -- SURROGATE-CODE-POINT, not TRUNCATED-SEQUENCE. Resuming by
    ;; a single octet after it would land mid-unit and either misdecode "b" or
    ;; signal spuriously; resuming by RESYNC-WIDTH (2 octets) lands back on a
    ;; unit boundary. This is the exact desync class %LENIENT-DECODE
    ;; (api.lisp) was fixed for; LENIENT-DECODE-PREFIX must not reintroduce it.
    (multiple-value-bind (string leftover)
        (lenient-decode-prefix (octets #x00 #x61 #xDC #x00 #x00 #x62) :encoding :utf-16be)
      (expect string :to-equal (format nil "a~Cb" #\REPLACEMENT_CHARACTER))
      (expect (length leftover) :to-be 0)))

  (it "signals STREAMING-UNSAFE-ENCODING for the generic, BOM-sensing designators"
    (dolist (encoding '(:utf-16 :utf-32 :ucs-2))
      (handler-case
          (progn (lenient-decode-prefix (octets #x00) :encoding encoding)
                 (error "expected STREAMING-UNSAFE-ENCODING for ~S" encoding))
        (streaming-unsafe-encoding (c)
          (expect (streaming-unsafe-encoding-designator c) :to-be encoding))))))
