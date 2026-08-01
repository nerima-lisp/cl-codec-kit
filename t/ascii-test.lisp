;;;; t/ascii-test.lisp
(in-package #:cl-codec-kit/test)

(describe
  "ASCII"
  (it "round-trips 7-bit text"
    (expect (octets-to-string (string-to-octets "Hello, World! 123" :encoding :ascii)
                              :encoding :ascii)
            :to-equal "Hello, World! 123"))

  (it-property "round-trips any 7-bit string, for any length"
      ((values (gen-scalar-string :max #x7F :min-length 0 :max-length 32)))
    (expect (octets-to-string (string-to-octets values :encoding :ascii) :encoding :ascii)
            :to-equal values))

  (it "signals INVALID-LEADING-BYTE on any octet above #x7F"
    (signals invalid-leading-byte (octets-to-string (octets #x80) :encoding :ascii)))

  (it "signals UNENCODABLE-CHARACTER for any character above U+007F"
    (signals unencodable-character (string-to-octets "café" :encoding :ascii)))

  (it "resolves the :US-ASCII alias to the same encoding"
    (expect (string-to-octets "hi" :encoding :us-ascii) :to-equal (string-to-octets "hi" :encoding :ascii))))
