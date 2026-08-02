;;;; src/utf-16.lisp
;;;;
;;;; UTF-16BE and UTF-16LE differ only in which byte of each 16-bit code unit
;;;; comes first, so %U16-DECODE and %U16-ENCODE take the byte order as a
;;;; keyword and every other function -- surrogate-pair assembly, code-unit
;;;; splitting -- is shared. Generic :UTF-16 senses a byte-order mark (BOM) on
;;;; decode and strips it via BOM-SENSING-DECODE (unicode.lisp); on encode it
;;;; always writes a big-endian BOM followed by big-endian content, since
;;;; Unicode's own spec states big-endian as the default assumption for
;;;; UTF-16 in the absence of a BOM.
(in-package #:cl-codec-kit)

(defparameter *utf-16-bom-be* #(#xFE #xFF)
  "UTF-16's big-endian byte-order mark. UCS-2 (ucs-2.lisp) reuses this: both
encodings share the same 16-bit code-unit layout and the same BOM.")
(defparameter *utf-16-bom-le* #(#xFF #xFE)
  "UTF-16's little-endian byte-order mark. See *UTF-16-BOM-BE*.")

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

(defun %u16-encode (string start end byte-order encoding-name)
  (let ((size 0))
    (loop for i from start below end
          for code = (char-code (char string i))
          do (when (or (surrogate-code-point-value-p code) (> code +max-code-point+))
               (error 'unencodable-character :char (char string i) :encoding encoding-name
                                             :position i))
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

(define-byte-order-encoding utf-16 (:aliases-be (:utf-16/be) :aliases-le (:utf-16/le)
                                     :resync-width 2 :default-replacement #\REPLACEMENT_CHARACTER)
  :core-decoder %u16-decode :core-encoder %u16-encode)

(defun utf-16-decode (octets start end)
  "Generic UTF-16: senses a BOM (FE FF for big-endian, FF FE for
little-endian) and strips it; defaults to big-endian when no BOM is present."
  (bom-sensing-decode octets start end *utf-16-bom-be* *utf-16-bom-le*
                       #'utf-16be-decode #'utf-16le-decode))

(defun utf-16-encode (string start end)
  (bom-sensing-encode *utf-16-bom-be* #'utf-16be-encode string start end))

(define-encoding :utf-16 (:resync-width 2 :bom-sensing-p t
                          :default-replacement #\REPLACEMENT_CHARACTER)
  :decoder utf-16-decode :encoder utf-16-encode)
