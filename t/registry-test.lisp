;;;; t/registry-test.lisp
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
