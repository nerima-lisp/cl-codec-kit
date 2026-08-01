;;;; src/utf-16.lisp
;;;;
;;;; UTF-16BE and UTF-16LE differ only in which byte of each 16-bit code unit
;;;; comes first, so %U16-DECODE and %U16-ENCODE take the byte order as a
;;;; keyword and every other function -- surrogate-pair assembly, code-unit
;;;; splitting -- is shared. Generic :UTF-16 senses a byte-order mark (BOM) on
;;;; decode and strips it; on encode it always writes a big-endian BOM
;;;; followed by big-endian content, since Unicode's own spec states
;;;; big-endian as the default assumption for UTF-16 in the absence of a BOM.
(in-package #:cl-codec-kit)

(defun %u16-read (octets index byte-order)
  (ecase byte-order
    (:be (logior (ash (aref octets index) 8) (aref octets (1+ index))))
    (:le (logior (aref octets index) (ash (aref octets (1+ index)) 8)))))

(defun %u16-write (unit result offset byte-order)
  (ecase byte-order
    (:be (setf (aref result offset) (ldb (byte 8 8) unit)
               (aref result (1+ offset)) (ldb (byte 8 0) unit)))
    (:le (setf (aref result offset) (ldb (byte 8 0) unit)
               (aref result (1+ offset)) (ldb (byte 8 8) unit)))))

(defun %u16-high-surrogate-p (unit) (<= #xD800 unit #xDBFF))
(defun %u16-low-surrogate-p (unit) (<= #xDC00 unit #xDFFF))

(defun %u16-decode-one (octets index end byte-order)
  "Decode one character starting at INDEX. Returns (values character
next-index)."
  (when (< (- end index) 2)
    (error 'truncated-sequence :position index))
  (let ((unit (%u16-read octets index byte-order)))
    (cond
      ((%u16-low-surrogate-p unit)
       (error 'surrogate-code-point :position index :value unit))
      ((%u16-high-surrogate-p unit)
       (when (< (- end index) 4)
         (error 'truncated-sequence :position index))
       (let ((low (%u16-read octets (+ index 2) byte-order)))
         (unless (%u16-low-surrogate-p low)
           (error 'surrogate-code-point :position index :value unit))
         (values (code-char (+ #x10000 (ash (- unit #xD800) 10) (- low #xDC00)))
                 (+ index 4))))
      (t (values (code-char unit) (+ index 2))))))

(defun %u16-decode (octets start end byte-order)
  (with-output-to-string (out)
    (loop with index = start
          while (< index end)
          do (multiple-value-bind (char next) (%u16-decode-one octets index end byte-order)
               (write-char char out)
               (setf index next)))))

(defun %u16-code-unit-count (code-point)
  (if (< code-point #x10000) 1 2))

(defun %u16-encode (string start end byte-order)
  (let ((size 0))
    (loop for i from start below end
          for code = (char-code (char string i))
          do (when (<= #xD800 code #xDFFF)
               (error 'unencodable-character :char (char string i) :encoding :utf-16))
             (when (> code #x10FFFF)
               (error 'unencodable-character :char (char string i) :encoding :utf-16))
             (incf size (* 2 (%u16-code-unit-count code))))
    (let ((result (make-array size :element-type '(unsigned-byte 8)))
          (offset 0))
      (loop for i from start below end
            for code = (char-code (char string i))
            do (if (< code #x10000)
                   (progn (%u16-write code result offset byte-order) (incf offset 2))
                   (let* ((adjusted (- code #x10000))
                          (high (+ #xD800 (ash adjusted -10)))
                          (low (+ #xDC00 (logand adjusted #x3FF))))
                     (%u16-write high result offset byte-order)
                     (%u16-write low result (+ offset 2) byte-order)
                     (incf offset 4))))
      result)))

(defun utf-16be-decode (octets start end) (%u16-decode octets start end :be))
(defun utf-16be-encode (string start end) (%u16-encode string start end :be))
(defun utf-16le-decode (octets start end) (%u16-decode octets start end :le))
(defun utf-16le-encode (string start end) (%u16-encode string start end :le))

(defun utf-16-decode (octets start end)
  "Generic UTF-16: senses a BOM (FE FF for big-endian, FF FE for
little-endian) and strips it; defaults to big-endian when no BOM is present."
  (if (>= (- end start) 2)
      (let ((first (aref octets start)) (second (aref octets (1+ start))))
        (cond
          ((and (= first #xFE) (= second #xFF)) (utf-16be-decode octets (+ start 2) end))
          ((and (= first #xFF) (= second #xFE)) (utf-16le-decode octets (+ start 2) end))
          (t (utf-16be-decode octets start end))))
      (utf-16be-decode octets start end)))

(defun utf-16-encode (string start end)
  (let ((body (utf-16be-encode string start end)))
    (concatenate '(vector (unsigned-byte 8)) #(#xFE #xFF) body)))

(define-encoding :utf-16be (:aliases (:utf-16/be)) :decoder utf-16be-decode :encoder utf-16be-encode)
(define-encoding :utf-16le (:aliases (:utf-16/le)) :decoder utf-16le-decode :encoder utf-16le-encode)
(define-encoding :utf-16 () :decoder utf-16-decode :encoder utf-16-encode)
