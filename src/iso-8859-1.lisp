;;;; src/iso-8859-1.lisp
;;;;
;;;; ISO-8859-1 (Latin-1): one octet per character, codespace U+0000-U+00FF,
;;;; with every octet value mapping directly to the identical code point.
;;;; Every other ISO-8859-N variant (2 through 16) needs a real per-encoding
;;;; mapping table above the Basic Latin range and is deferred -- see the
;;;; project's docs/src/roadmap.md for what is and is not implemented.
(in-package #:cl-codec-kit)

(defun iso-8859-1-decode (octets start end)
  (let ((result (make-string (- end start))))
    (loop for index from start below end
          do (setf (char result (- index start)) (code-char (aref octets index))))
    result))

(defun iso-8859-1-encode (string start end)
  (let ((result (make-array (- end start) :element-type '(unsigned-byte 8))))
    (loop for i from start below end
          for code = (char-code (char string i))
          do (when (> code #xFF)
               (error 'unencodable-character :char (char string i) :encoding :iso-8859-1))
             (setf (aref result (- i start)) code))
    result))

(define-encoding :iso-8859-1 (:aliases (:latin-1 :latin1))
  :decoder iso-8859-1-decode :encoder iso-8859-1-encode)
