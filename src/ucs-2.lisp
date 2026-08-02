;;;; src/ucs-2.lisp
;;;;
;;;; UCS-2 predates surrogate pairs: every code unit is a complete BMP code
;;;; point (U+0000-U+FFFF) on its own, and a code unit that falls in the
;;;; surrogate range (U+D800-U+DFFF) is malformed rather than half of a pair.
;;;; Reuses %U16-READ/%U16-WRITE from utf-16.lisp -- the byte-order bit
;;;; operations are identical, only the per-unit interpretation differs.
(in-package #:cl-codec-kit)

(defun %ucs2-decode (octets start end byte-order)
  (with-output-to-string (out)
    (loop with index = start
          while (< index end)
          do (when (< (- end index) 2)
               (error 'truncated-sequence :position index))
             (let ((unit (%u16-read octets index byte-order)))
               (when (surrogate-code-point-value-p unit)
                 (error 'surrogate-code-point :position index :value unit))
               (write-char (code-char unit) out))
             (incf index 2))))

(defun %ucs2-encode (string start end byte-order encoding-name)
  (let ((result (make-array (* 2 (- end start)) :element-type '(unsigned-byte 8))))
    (loop for i from start below end
          for offset = (* 2 (- i start))
          for code = (char-code (char string i))
          do (when (or (> code #xFFFF) (surrogate-code-point-value-p code))
               (error 'unencodable-character :char (char string i) :encoding encoding-name
                                             :position i))
             (%u16-write code result offset byte-order))
    result))

(define-byte-order-encoding ucs-2 (:aliases-be (:ucs-2/be) :aliases-le (:ucs-2/le)
                                    :resync-width 2 :default-replacement #\REPLACEMENT_CHARACTER)
  :core-decoder %ucs2-decode :core-encoder %ucs2-encode)

(defun ucs-2-decode (octets start end)
  "Generic UCS-2: senses a BOM using the same two-octet marks as UTF-16
(*UTF-16-BOM-BE*/*UTF-16-BOM-LE*, utf-16.lisp) and strips it; defaults to
big-endian when no BOM is present."
  (bom-sensing-decode octets start end *utf-16-bom-be* *utf-16-bom-le*
                       #'ucs-2be-decode #'ucs-2le-decode))

(defun ucs-2-encode (string start end)
  (bom-sensing-encode *utf-16-bom-be* #'ucs-2be-encode string start end))

(define-encoding :ucs-2 (:resync-width 2 :bom-sensing-p t
                         :default-replacement #\REPLACEMENT_CHARACTER)
  :decoder ucs-2-decode :encoder ucs-2-encode)
