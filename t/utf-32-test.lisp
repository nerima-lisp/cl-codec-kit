;;;; t/utf-32-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "UTF-32"
  (it "round-trips text through BE and LE"
    (dolist (encoding '(:utf-32be :utf-32le))
      (dolist (s (list "" "hello" "日本語" "😀"))
        (expect (octets-to-string (string-to-octets s :encoding encoding) :encoding encoding)
                :to-equal s))))

  (it-property "round-trips any scalar-value string through BE, for any length"
      ((values (gen-scalar-string :max #x10FFFF :min-length 0 :max-length 24)))
    (expect (octets-to-string (string-to-octets values :encoding :utf-32be) :encoding :utf-32be)
            :to-equal values))

  (it "encodes a code point as 4 big-endian octets"
    ;; :TO-EQUALP, not :TO-EQUAL: CL:EQUAL falls through to EQ on octet
    ;; vectors and would pass regardless of content.
    (expect (string-to-octets (string (code-char #x10348)) :encoding :utf-32be)
            :to-equalp (octets #x00 #x01 #x03 #x48)))

  (it "senses a byte-order mark for generic :UTF-32 and strips it"
    (expect (octets-to-string (octets #x00 #x00 #xFE #xFF #x00 #x00 #x00 #x41) :encoding :utf-32)
            :to-equal "A")
    (expect (octets-to-string (octets #xFF #xFE #x00 #x00 #x41 #x00 #x00 #x00) :encoding :utf-32)
            :to-equal "A"))

  (it "signals SURROGATE-CODE-POINT and CODE-POINT-TOO-LARGE"
    (signals surrogate-code-point
        (octets-to-string (octets #x00 #x00 #xD8 #x00) :encoding :utf-32be))
    (signals code-point-too-large
        (octets-to-string (octets #x00 #x11 #x00 #x00) :encoding :utf-32be)))

  (it "signals TRUNCATED-SEQUENCE when fewer than 4 octets remain"
    (signals truncated-sequence (octets-to-string (octets #x00 #x00 #x00) :encoding :utf-32be)))

  (it ":ERRORP NIL resyncs by whole 4-octet code units, not by one octet"
    (let ((result (octets-to-string (octets #x00 #x11 #x00 #x00 #x00 #x00 #x00 #x42)
                                    :encoding :utf-32be :errorp nil)))
      (expect (length result) :to-be 2)
      (expect (char-code (char result 0)) :to-be #x1a)
      (expect (char result 1) :to-be #\B))))
