;;;; t/ucs-2-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "UCS-2"
  (it "round-trips BMP text through BE and LE"
    (dolist (encoding '(:ucs-2be :ucs-2le))
      (dolist (s (list "" "hello" "日本語"))
        (expect (octets-to-string (string-to-octets s :encoding encoding) :encoding encoding)
                :to-equal s))))

  (it-round-trips :ucs-2be :max #xFFFF)

  (it "senses a byte-order mark for generic :UCS-2"
    (expect (octets-to-string (octets #xFE #xFF #x00 #x41) :encoding :ucs-2) :to-equal "A"))

  (it "signals UNENCODABLE-CHARACTER for a supplementary-plane character"
    (signals unencodable-character
        (string-to-octets (string (code-char #x10348)) :encoding :ucs-2be)))

  (it "signals SURROGATE-CODE-POINT on a surrogate code unit, since UCS-2 has no pairing"
    (signals surrogate-code-point (octets-to-string (octets #xD8 #x00) :encoding :ucs-2be)))

  (it ":ERRORP NIL resyncs by whole 2-octet code units, not by one octet"
    (with-soft-assertions
      (let ((result (octets-to-string (octets #xD8 #x00 #x00 #x42) :encoding :ucs-2be :errorp nil)))
        (expect (length result) :to-be 2)
        (expect (char result 0) :to-be #\REPLACEMENT_CHARACTER)
        (expect (char result 1) :to-be #\B)))))
