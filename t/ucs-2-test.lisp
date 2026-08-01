;;;; t/ucs-2-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "UCS-2"
  (it "round-trips BMP text through BE and LE"
    (dolist (encoding '(:ucs-2be :ucs-2le))
      (dolist (s (list "" "hello" "日本語"))
        (expect (octets-to-string (string-to-octets s :encoding encoding) :encoding encoding)
                :to-equal s))))

  (it-property "round-trips any BMP string through BE, for any length"
      ((values (gen-scalar-string :max #xFFFF :min-length 0 :max-length 24)))
    (expect (octets-to-string (string-to-octets values :encoding :ucs-2be) :encoding :ucs-2be)
            :to-equal values))

  (it "senses a byte-order mark for generic :UCS-2"
    (expect (octets-to-string (octets #xFE #xFF #x00 #x41) :encoding :ucs-2) :to-equal "A"))

  (it "signals UNENCODABLE-CHARACTER for a supplementary-plane character"
    (signals unencodable-character
        (string-to-octets (string (code-char #x10348)) :encoding :ucs-2be)))

  (it "signals SURROGATE-CODE-POINT on a surrogate code unit, since UCS-2 has no pairing"
    (signals surrogate-code-point (octets-to-string (octets #xD8 #x00) :encoding :ucs-2be)))

  (it ":ERRORP NIL resyncs by whole 2-octet code units, not by one octet"
    (let ((result (octets-to-string (octets #xD8 #x00 #x00 #x42) :encoding :ucs-2be :errorp nil)))
      (expect (length result) :to-be 2)
      (expect (char-code (char result 0)) :to-be #x1a)
      (expect (char result 1) :to-be #\B))))
