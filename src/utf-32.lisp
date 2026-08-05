;;;; src/utf-32.lisp
;;;;
;;;; UTF-32 fixes every code point at 4 octets, so there is no multi-unit
;;;; assembly like UTF-16's surrogate pairs -- only byte order and the same
;;;; surrogate/out-of-range rejection every encoding here applies.
(in-package #:cl-codec-kit)

(defparameter *utf-32-bom-be* #(0 0 #xFE #xFF) "UTF-32's big-endian byte-order mark.")
(defparameter *utf-32-bom-le* #(#xFF #xFE 0 0) "UTF-32's little-endian byte-order mark.")

(defun %u32-read (octets index byte-order)
  (ecase byte-order
    (:be (logior (ash (aref octets index) 24) (ash (aref octets (1+ index)) 16)
                 (ash (aref octets (+ index 2)) 8) (aref octets (+ index 3))))
    (:le (logior (aref octets index) (ash (aref octets (1+ index)) 8)
                 (ash (aref octets (+ index 2)) 16) (ash (aref octets (+ index 3)) 24)))))

(defun %u32-write (code-point result offset byte-order)
  (ecase byte-order
    (:be (setf (aref result offset) (ldb (byte 8 24) code-point)
               (aref result (1+ offset)) (ldb (byte 8 16) code-point)
               (aref result (+ offset 2)) (ldb (byte 8 8) code-point)
               (aref result (+ offset 3)) (ldb (byte 8 0) code-point)))
    (:le (setf (aref result offset) (ldb (byte 8 0) code-point)
               (aref result (1+ offset)) (ldb (byte 8 8) code-point)
               (aref result (+ offset 2)) (ldb (byte 8 16) code-point)
               (aref result (+ offset 3)) (ldb (byte 8 24) code-point)))))

(defun %u32-decode (octets start end byte-order)
  (with-output-to-string (out)
    (loop with index = start
          while (< index end)
          do (when (< (- end index) 4)
               (error 'truncated-sequence :position index))
             (let ((code-point (%u32-read octets index byte-order)))
               (when (surrogate-code-point-value-p code-point)
                 (error 'surrogate-code-point :position index :value code-point))
               (when (> code-point +max-code-point+)
                 (error 'code-point-too-large :position index :value code-point))
               (write-char (code-char code-point) out))
             (incf index 4))))

(defun %u32-encode (string start end byte-order encoding-name)
  (let ((result (make-array (* 4 (- end start)) :element-type '(unsigned-byte 8))))
    (loop for i from start below end
          for offset = (* 4 (- i start))
          for code = (char-code (char string i))
          do (when (or (surrogate-code-point-value-p code) (> code +max-code-point+))
               (error 'unencodable-character :char (char string i) :encoding encoding-name
                                             :position i))
             (%u32-write code result offset byte-order))
    result))

(define-byte-order-encoding utf-32 (:aliases-be (:utf-32/be :ucs-4be :ucs-4/be)
                                     :aliases-le (:utf-32/le :ucs-4le :ucs-4/le)
                                     :resync-width 4 :default-replacement #\REPLACEMENT_CHARACTER)
  :core-decoder %u32-decode :core-encoder %u32-encode)

(defun utf-32-decode (octets start end)
  "Generic UTF-32: senses a 4-octet BOM and strips it; defaults to big-endian
when no BOM is present, matching generic UTF-16's convention here."
  (bom-sensing-decode octets start end *utf-32-bom-be* *utf-32-bom-le*
                       #'utf-32be-decode #'utf-32le-decode))

(defun utf-32-encode (string start end)
  (bom-sensing-encode *utf-32-bom-be* #'utf-32be-encode string start end))

(define-encoding :utf-32 (:aliases (:ucs-4) :resync-width 4 :bom-sensing-p t
                          :default-replacement #\REPLACEMENT_CHARACTER)
  :decoder utf-32-decode :encoder utf-32-encode)
