;;;; src/single-octet.lisp
;;;;
;;;; Data and logic shared by every single-octet encoding this library
;;;; implements (ASCII, ISO-8859-1): one octet per character, every octet
;;;; value below the encoding's own MAX-CODE-POINT mapping directly to the
;;;; identical code point. No multi-byte sequence exists in this family, so
;;;; no TRUNCATED-SEQUENCE case ever applies -- every octet decodes
;;;; independently, unlike unicode.lisp's BOM-sensing, multi-unit family.
(in-package #:cl-codec-kit)

(defmacro define-single-octet-encoding (name (&key aliases (max-code-point #xFF)
                                                    default-replacement))
  "Register NAME (and each of ALIASES) as a CHARACTER-ENCODING whose
codespace is U+0000-MAX-CODE-POINT, with every octet in that range mapping
directly to the identical code point. Defines NAME-DECODE/NAME-ENCODE and
registers them via DEFINE-ENCODING (registry.lisp) with the RESYNC-WIDTH/
BOM-SENSING-P defaults already correct for a byte-oriented, fixed-order,
non-Unicode encoding -- the same defaults ASCII and ISO-8859-1 relied on
before this macro existed.

Decode only range-checks octets against MAX-CODE-POINT when it is below
#xFF: every octet an (UNSIGNED-BYTE 8) array element can hold is already
<= #xFF, so a MAX-CODE-POINT of #xFF (ISO-8859-1's codespace) never has an
out-of-range octet to reject, and generating that dead check would leave
untestable, unreachable code behind -- exactly what ISO-8859-1-DECODE's
former hand-written body already omitted."
  (let* ((base (symbol-name name))
         (decode-name (intern (format nil "~A-DECODE" base)))
         (encode-name (intern (format nil "~A-ENCODE" base)))
         (keyword (intern base :keyword)))
    `(progn
       (defun ,decode-name (octets start end)
         ,(if (< max-code-point #xFF)
              `(with-output-to-string (out)
                 (loop for index from start below end
                       for octet = (aref octets index)
                       do (when (> octet ,max-code-point)
                            (error 'invalid-leading-byte :position index :octet octet))
                          (write-char (code-char octet) out)))
              `(let ((result (make-string (- end start))))
                 (loop for index from start below end
                       do (setf (char result (- index start)) (code-char (aref octets index))))
                 result)))
       (defun ,encode-name (string start end)
         (let ((result (make-array (- end start) :element-type '(unsigned-byte 8))))
           (loop for i from start below end
                 for code = (char-code (char string i))
                 do (when (> code ,max-code-point)
                      (error 'unencodable-character :char (char string i) :encoding ,keyword
                                                    :position i))
                    (setf (aref result (- i start)) code))
           result))
       (define-encoding ,keyword (:aliases ,aliases
                                   ,@(when default-replacement
                                       `(:default-replacement ,default-replacement)))
         :decoder ,decode-name :encoder ,encode-name))))
