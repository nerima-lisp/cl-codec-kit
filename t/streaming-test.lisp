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
    (multiple-value-bind (string leftover) (decode-prefix (string-to-octets "café" :encoding :utf-8)
                                                           :encoding :utf-8)
      (expect string :to-equal "café")
      (expect (length leftover) :to-be 0)))

  (it "splits UTF-8 at the last complete character, leaving a truncated tail"
    (let ((full (string-to-octets "café" :encoding :utf-8)))
      (multiple-value-bind (string leftover) (decode-prefix full :end (1- (length full)) :encoding :utf-8)
        (expect string :to-equal "caf")
        (expect (length leftover) :to-be 1))))

  (it "splits UTF-16 at a character boundary that falls mid-surrogate-pair"
    (let ((full (string-to-octets "a😀" :encoding :utf-16be)))
      (multiple-value-bind (string leftover) (decode-prefix full :end (1- (length full)) :encoding :utf-16be)
        (expect string :to-equal "a")
        (expect (length leftover) :to-be 3))))

  (it "propagates a genuinely invalid sequence rather than treating it as a boundary"
    (signals invalid-leading-byte
        (decode-prefix (octets #x41 #x80) :encoding :utf-8)))

  (it "reassembles to the original string when the leftover is fed back in with more data"
    (let* ((full (string-to-octets "hello 日本語 world" :encoding :utf-8)))
      (loop for cut from 0 to (length full)
            do (multiple-value-bind (string leftover) (decode-prefix full :end cut :encoding :utf-8)
                 (expect (concatenate 'string string
                                      (octets-to-string (concatenate '(vector (unsigned-byte 8))
                                                                     leftover (subseq full cut))
                                                        :encoding :utf-8))
                         :to-equal "hello 日本語 world"))))))
