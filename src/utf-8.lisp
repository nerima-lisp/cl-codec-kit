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

(defun %utf8-sequence-length (leading-byte)
  "Return the total octet length (1-4) of the sequence LEADING-BYTE starts, or
NIL if LEADING-BYTE cannot start any valid UTF-8 sequence."
  (cond
    ((< leading-byte #x80) 1)
    ((<= #xC2 leading-byte #xDF) 2)
    ((<= #xE0 leading-byte #xEF) 3)
    ((<= #xF0 leading-byte #xF4) 4)
    (t nil)))

(defun %utf8-min-code-point (sequence-length)
  (ecase sequence-length (1 0) (2 #x80) (3 #x800) (4 #x10000)))

(defun %utf8-decode-one (octets index end)
  "Decode one character from OCTETS starting at INDEX, never reading at or
past END. Returns (values character next-index)."
  (let ((first (aref octets index)))
    (if (< first #x80)
        (values (code-char first) (1+ index))
        (let ((length (%utf8-sequence-length first)))
          (unless length
            (error 'invalid-leading-byte :position index :octet first))
          (let ((available (- end index 1)))
            ;; An invalid continuation byte is never a truncation, no matter
            ;; how few bytes remain -- check every available one first.
            (loop for offset from 1 below (min length (1+ available))
                  for byte = (aref octets (+ index offset))
                  unless (%utf8-continuation-octet-p byte)
                    do (error 'invalid-continuation-byte :position (+ index offset) :octet byte))
            (when (< available (1- length))
              (error 'truncated-sequence :position index)))
          (let ((code-point
                  (case length
                    (2 (logior (ash (logand first #x1F) 6)
                               (logand (aref octets (+ index 1)) #x3F)))
                    (3 (logior (ash (logand first #x0F) 12)
                               (ash (logand (aref octets (+ index 1)) #x3F) 6)
                               (logand (aref octets (+ index 2)) #x3F)))
                    (4 (logior (ash (logand first #x07) 18)
                               (ash (logand (aref octets (+ index 1)) #x3F) 12)
                               (ash (logand (aref octets (+ index 2)) #x3F) 6)
                               (logand (aref octets (+ index 3)) #x3F))))))
            (when (< code-point (%utf8-min-code-point length))
              (error 'overlong-sequence :position index))
            (when (<= #xD800 code-point #xDFFF)
              (error 'surrogate-code-point :position index :value code-point))
            (when (> code-point #x10FFFF)
              (error 'code-point-too-large :position index :value code-point))
            (values (code-char code-point) (+ index length)))))))

(defun utf-8-decode (octets start end)
  (with-output-to-string (out)
    (loop with index = start
          while (< index end)
          do (multiple-value-bind (char next) (%utf8-decode-one octets index end)
               (write-char char out)
               (setf index next)))))

(defun %utf8-encoded-length (code-point char)
  "Return the octet length CODE-POINT needs in UTF-8, or signal
UNENCODABLE-CHARACTER for a surrogate half or an out-of-range code point."
  (cond
    ((< code-point #x80) 1)
    ((< code-point #x800) 2)
    ((<= #xD800 code-point #xDFFF) (error 'unencodable-character :char char :encoding :utf-8))
    ((< code-point #x10000) 3)
    ((<= code-point #x10FFFF) 4)
    (t (error 'unencodable-character :char char :encoding :utf-8))))

(defun utf-8-encode (string start end)
  (let ((size 0))
    (loop for i from start below end
          do (incf size (%utf8-encoded-length (char-code (char string i)) (char string i))))
    (let ((result (make-array size :element-type '(unsigned-byte 8)))
          (offset 0))
      (loop for i from start below end
            for code = (char-code (char string i))
            do (cond
                 ((< code #x80)
                  (setf (aref result offset) code)
                  (incf offset 1))
                 ((< code #x800)
                  (setf (aref result offset) (logior #xC0 (ash code -6))
                        (aref result (+ offset 1)) (logior #x80 (logand code #x3F)))
                  (incf offset 2))
                 ((< code #x10000)
                  (setf (aref result offset) (logior #xE0 (ash code -12))
                        (aref result (+ offset 1)) (logior #x80 (logand (ash code -6) #x3F))
                        (aref result (+ offset 2)) (logior #x80 (logand code #x3F)))
                  (incf offset 3))
                 (t
                  (setf (aref result offset) (logior #xF0 (ash code -18))
                        (aref result (+ offset 1)) (logior #x80 (logand (ash code -12) #x3F))
                        (aref result (+ offset 2)) (logior #x80 (logand (ash code -6) #x3F))
                        (aref result (+ offset 3)) (logior #x80 (logand code #x3F)))
                  (incf offset 4))))
      result)))

(define-encoding :utf-8 ()
  :decoder utf-8-decode
  :encoder utf-8-encode)
