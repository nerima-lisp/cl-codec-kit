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
               (when (<= #xD800 unit #xDFFF)
                 (error 'surrogate-code-point :position index :value unit))
               (write-char (code-char unit) out))
             (incf index 2))))

(defun %ucs2-encode (string start end byte-order encoding-name)
  (let ((result (make-array (* 2 (- end start)) :element-type '(unsigned-byte 8))))
    (loop for i from start below end
          for offset = (* 2 (- i start))
          for code = (char-code (char string i))
          do (when (or (> code #xFFFF) (<= #xD800 code #xDFFF))
               (error 'unencodable-character :char (char string i) :encoding encoding-name
                                             :position i))
             (%u16-write code result offset byte-order))
    result))

(defun ucs-2be-decode (octets start end) (%ucs2-decode octets start end :be))
(defun ucs-2be-encode (string start end) (%ucs2-encode string start end :be :ucs-2be))
(defun ucs-2le-decode (octets start end) (%ucs2-decode octets start end :le))
(defun ucs-2le-encode (string start end) (%ucs2-encode string start end :le :ucs-2le))

(defun ucs-2-decode (octets start end)
  (if (>= (- end start) 2)
      (let ((first (aref octets start)) (second (aref octets (1+ start))))
        (cond
          ((and (= first #xFE) (= second #xFF)) (ucs-2be-decode octets (+ start 2) end))
          ((and (= first #xFF) (= second #xFE)) (ucs-2le-decode octets (+ start 2) end))
          (t (ucs-2be-decode octets start end))))
      (ucs-2be-decode octets start end)))

(defun ucs-2-encode (string start end)
  (concatenate '(vector (unsigned-byte 8)) #(#xFE #xFF) (ucs-2be-encode string start end)))

(define-encoding :ucs-2be (:aliases (:ucs-2/be) :resync-width 2)
  :decoder ucs-2be-decode :encoder ucs-2be-encode)
(define-encoding :ucs-2le (:aliases (:ucs-2/le) :resync-width 2)
  :decoder ucs-2le-decode :encoder ucs-2le-encode)
(define-encoding :ucs-2 (:resync-width 2 :bom-sensing-p t)
  :decoder ucs-2-decode :encoder ucs-2-encode)
