;;;; t/iso-8859-1-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "ISO-8859-1"
  (it "round-trips 8-bit text including the upper Latin-1 range"
    (expect (octets-to-string (string-to-octets "café ñ" :encoding :iso-8859-1)
                              :encoding :iso-8859-1)
            :to-equal "café ñ"))

  (it-property "round-trips any 8-bit string, for any length"
      ((values (gen-scalar-string :max #xFF :min-length 0 :max-length 32)))
    (expect (octets-to-string (string-to-octets values :encoding :iso-8859-1) :encoding :iso-8859-1)
            :to-equal values))

  (it "maps every octet directly to the same code point"
    (expect (octets-to-string (octets #xE9) :encoding :iso-8859-1) :to-equal (string (code-char #xE9))))

  (it "signals UNENCODABLE-CHARACTER above U+00FF"
    (signals unencodable-character (string-to-octets "日" :encoding :iso-8859-1)))

  (it "resolves the :LATIN-1 and :LATIN1 aliases"
    (expect (string-to-octets "x" :encoding :latin-1) :to-equal (string-to-octets "x" :encoding :iso-8859-1))
    (expect (string-to-octets "x" :encoding :latin1) :to-equal (string-to-octets "x" :encoding :iso-8859-1))))
