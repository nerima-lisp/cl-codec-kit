;;;; t/iso-8859-1-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "ISO-8859-1"
  (it "round-trips 8-bit text including the upper Latin-1 range"
    (expect (octets-to-string (string-to-octets "café ñ" :encoding :iso-8859-1)
                              :encoding :iso-8859-1)
            :to-equal "café ñ"))

  (it-round-trips :iso-8859-1 :max #xFF :max-length 32)

  (it "maps every octet directly to the same code point"
    (expect (octets-to-string (octets #xE9) :encoding :iso-8859-1)
            :to-equal (string (code-char #xE9))))

  (it "signals UNENCODABLE-CHARACTER above U+00FF"
    (signals unencodable-character (string-to-octets "日" :encoding :iso-8859-1)))

  ;; :TO-EQUALP, not :TO-EQUAL: CL:EQUAL falls through to EQ on octet
  ;; vectors and would pass regardless of content.
  (it "resolves the :LATIN-1 and :LATIN1 aliases"
    (expect (string-to-octets "x" :encoding :latin-1)
            :to-equalp (string-to-octets "x" :encoding :iso-8859-1))
    (expect (string-to-octets "x" :encoding :latin1)
            :to-equalp (string-to-octets "x" :encoding :iso-8859-1))))
