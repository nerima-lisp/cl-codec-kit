(in-package #:cl-codec-kit/test)

(describe
  "the encoding registry"
  (it "lists every canonical encoding registered by this library's encoding files"
    (let ((names (list-character-encodings)))
      (dolist (expected '(:utf-8 :utf-16 :utf-16be :utf-16le :utf-32 :utf-32be :utf-32le
                          :ucs-2 :ucs-2be :ucs-2le :ascii :iso-8859-1))
        (expect (member expected names) :to-be-truthy))))

  (it "FIND-CHARACTER-ENCODING resolves both canonical names and aliases to the same object"
    (expect (find-character-encoding :iso-8859-1) :to-be (find-character-encoding :latin-1)))

  (it "signals UNSUPPORTED-ENCODING for an unregistered designator"
    (signals unsupported-encoding (find-character-encoding :not-a-real-encoding)))

  (it "*DEFAULT-ENCODING* is :UTF-8 and is honored when :ENCODING is omitted"
    (expect *default-encoding* :to-be :utf-8)
    (expect (octets-to-string (string-to-octets "café")) :to-equal "café")))

(describe
  "CHARACTER-ENCODING-DEFAULT-REPLACEMENT, per encoding"
  (it-each ((:utf-8 #xFFFD) (:utf-16 #xFFFD) (:utf-16be #xFFFD) (:utf-16le #xFFFD)
            (:utf-32 #xFFFD) (:utf-32be #xFFFD) (:utf-32le #xFFFD)
            (:ucs-2 #xFFFD) (:ucs-2be #xFFFD) (:ucs-2le #xFFFD)
            (:ascii #x1A) (:iso-8859-1 #x1A))
      "~A's default replacement is U+~4,'0X"
      (name expected-code)
    (expect (char-code (character-encoding-default-replacement (find-character-encoding name)))
            :to-be expected-code))

  (it "is U+001A (SUB), not U+FFFD, because the single-octet encodings cannot represent U+FFFD"
    (dolist (name '(:ascii :iso-8859-1))
      (signals unencodable-character
          (string-to-octets (string #\REPLACEMENT_CHARACTER) :encoding name))))

  (it "is set for every registered encoding, so no caller can reach an unset default"
    (dolist (name (list-character-encodings))
      (expect (characterp (character-encoding-default-replacement
                           (find-character-encoding name)))
              :to-be-truthy)))

  (it "is itself encodable in its own encoding, for every registered encoding"
    (dolist (name (list-character-encodings))
      (let ((replacement (character-encoding-default-replacement
                          (find-character-encoding name))))
        (expect (plusp (length (string-to-octets (string replacement) :encoding name)))
                :to-be-truthy)))))

(describe
  "every registered encoding's strict decoder"
  (it-fuzz "OCTETS-TO-STRING never signals outside the DECODE-ERROR hierarchy"
      ((bytes (gen-octets :min-length 0 :max-length 12))
       (encoding (gen-member (list-character-encodings))))
      (:trials 300)
    (handler-case (octets-to-string bytes :encoding encoding)
      (decode-error () nil))))
