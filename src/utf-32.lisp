;;;; src/utf-32.lisp
;;;;
;;;; UTF-32 fixes every code point at 4 octets, so there is no multi-unit
;;;; assembly like UTF-16's surrogate pairs -- only byte order and the same
;;;; surrogate/out-of-range rejection every encoding here applies.
(in-package #:cl-codec-kit)

(defun %u32-read (octets index byte-order)
  (ecase byte-order
    (:be (logior (ash (aref octets index) 24) (ash (aref octets (+ index 1)) 16)
                 (ash (aref octets (+ index 2)) 8) (aref octets (+ index 3))))
    (:le (logior (aref octets index) (ash (aref octets (+ index 1)) 8)
                 (ash (aref octets (+ index 2)) 16) (ash (aref octets (+ index 3)) 24)))))

(defun %u32-write (code-point result offset byte-order)
  (ecase byte-order
    (:be (setf (aref result offset) (ldb (byte 8 24) code-point)
               (aref result (+ offset 1)) (ldb (byte 8 16) code-point)
               (aref result (+ offset 2)) (ldb (byte 8 8) code-point)
               (aref result (+ offset 3)) (ldb (byte 8 0) code-point)))
    (:le (setf (aref result offset) (ldb (byte 8 0) code-point)
               (aref result (+ offset 1)) (ldb (byte 8 8) code-point)
               (aref result (+ offset 2)) (ldb (byte 8 16) code-point)
               (aref result (+ offset 3)) (ldb (byte 8 24) code-point)))))

(defun %u32-decode (octets start end byte-order)
  (with-output-to-string (out)
    (loop with index = start
          while (< index end)
          do (when (< (- end index) 4)
               (error 'truncated-sequence :position index))
             (let ((code-point (%u32-read octets index byte-order)))
               (when (<= #xD800 code-point #xDFFF)
                 (error 'surrogate-code-point :position index :value code-point))
               (when (> code-point #x10FFFF)
                 (error 'code-point-too-large :position index :value code-point))
               (write-char (code-char code-point) out))
             (incf index 4))))

(defun %u32-encode (string start end byte-order encoding-name)
  (let ((result (make-array (* 4 (- end start)) :element-type '(unsigned-byte 8))))
    (loop for i from start below end
          for offset = (* 4 (- i start))
          for code = (char-code (char string i))
          do (when (or (<= #xD800 code #xDFFF) (> code #x10FFFF))
               (error 'unencodable-character :char (char string i) :encoding encoding-name))
             (%u32-write code result offset byte-order))
    result))

(defun utf-32be-decode (octets start end) (%u32-decode octets start end :be))
(defun utf-32be-encode (string start end) (%u32-encode string start end :be :utf-32be))
(defun utf-32le-decode (octets start end) (%u32-decode octets start end :le))
(defun utf-32le-encode (string start end) (%u32-encode string start end :le :utf-32le))

(defun utf-32-decode (octets start end)
  "Generic UTF-32: senses a 4-octet BOM and strips it; defaults to big-endian
when no BOM is present, matching generic UTF-16's convention here."
  (if (>= (- end start) 4)
      (let ((a (aref octets start)) (b (aref octets (1+ start)))
            (c (aref octets (+ start 2))) (d (aref octets (+ start 3))))
        (cond
          ((and (= a 0) (= b 0) (= c #xFE) (= d #xFF)) (utf-32be-decode octets (+ start 4) end))
          ((and (= a #xFF) (= b #xFE) (= c 0) (= d 0)) (utf-32le-decode octets (+ start 4) end))
          (t (utf-32be-decode octets start end))))
      (utf-32be-decode octets start end)))

(defun utf-32-encode (string start end)
  (concatenate '(vector (unsigned-byte 8)) #(0 0 #xFE #xFF) (utf-32be-encode string start end)))

(define-encoding :utf-32be (:aliases (:utf-32/be :ucs-4be :ucs-4/be) :resync-width 4)
  :decoder utf-32be-decode :encoder utf-32be-encode)
(define-encoding :utf-32le (:aliases (:utf-32/le :ucs-4le :ucs-4/le) :resync-width 4)
  :decoder utf-32le-decode :encoder utf-32le-encode)
(define-encoding :utf-32 (:aliases (:ucs-4) :resync-width 4 :bom-sensing-p t)
  :decoder utf-32-decode :encoder utf-32-encode)
