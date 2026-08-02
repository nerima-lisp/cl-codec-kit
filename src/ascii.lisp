;;;; src/ascii.lisp
;;;;
;;;; 7-bit ASCII: the simplest encoding here, one octet per character,
;;;; codespace U+0000-U+007F. No multi-byte sequence exists, so no
;;;; TRUNCATED-SEQUENCE case applies -- every octet decodes independently.
(in-package #:cl-codec-kit)

(defun ascii-decode (octets start end)
  (with-output-to-string (out)
    (loop for index from start below end
          for octet = (aref octets index)
          do (when (> octet #x7F)
               (error 'invalid-leading-byte :position index :octet octet))
             (write-char (code-char octet) out))))

(defun ascii-encode (string start end)
  (let ((result (make-array (- end start) :element-type '(unsigned-byte 8))))
    (loop for i from start below end
          for code = (char-code (char string i))
          do (when (> code #x7F)
               (error 'unencodable-character :char (char string i) :encoding :ascii :position i))
             (setf (aref result (- i start)) code))
    result))

;; No :DEFAULT-REPLACEMENT: ASCII takes DEFINE-ENCODING's own #x1A (SUB)
;; default, which is both what babel's single-octet codecs substitute and the
;; only choice encodable here -- U+FFFD is outside this codespace entirely.
(define-encoding :ascii (:aliases (:us-ascii)) :decoder ascii-decode :encoder ascii-encode)
