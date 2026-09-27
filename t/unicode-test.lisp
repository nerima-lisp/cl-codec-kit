(in-package #:cl-codec-kit/test)

(describe
  "the surrogate-range boundary check every codec here shares"
  (it "kills every mutation of the boundary comparison with a perfect score"
    (let ((results
            (run-mutations
             '(and (not (<= #xD800 0))            ; codespace minimum
                   (not (<= #xD800 #xD7FF))        ; one below the range
                   (<= #xD800 #xD800 #xDFFF)       ; range minimum
                   (<= #xD800 #xDBFF #xDFFF)       ; last high surrogate
                   (<= #xD800 #xDC00 #xDFFF)       ; first low surrogate
                   (<= #xD800 #xDFFF #xDFFF)       ; range maximum
                   (not (<= #xE000 #xDFFF))        ; one above the range
                   (not (<= #x10FFFF #xDFFF)))     ; codespace maximum
             (lambda (form mutation)
               (declare (ignore mutation))
               (eq (eval form) t)))))
      (assert-mutation-score results 1.0))))
(describe
  "UNICODE ENCODING DETECTION"
  (it "checks UTF-32 BOMs before UTF-16 BOMs and recognizes every Unicode BOM"
    (dolist (case '((:utf-32be 4 (0 0 #xFE #xFF #x00 #x00 #x00 #x41))
                    (:utf-32le 4 (#xFF #xFE 0 0 #x41 0 0 0))
                    (:utf-16be 2 (#xFE #xFF 0 #x41))
                    (:utf-16le 2 (#xFF #xFE #x41 0))
                    (:utf-8 3 (#xEF #xBB #xBF #x41))))
      (destructuring-bind (expected-encoding expected-bom-length bytes) case
        (multiple-value-bind (encoding bom-length)
            (detect-unicode-encoding (apply #'octets bytes))
          (expect encoding :to-be expected-encoding)
          (expect bom-length :to-be expected-bom-length)))))
  (it "recognizes BOM-less null patterns and defaults to UTF-8 otherwise"
    (dolist (case '((:utf-32be (0 0 0 #x41))
                    (:utf-32le (#x41 0 0 0))
                    (:utf-16be (0 #x41))
                    (:utf-16le (#x41 0))
                    (:utf-8 (#x41 #x42))))
      (destructuring-bind (expected-encoding bytes) case
        (multiple-value-bind (encoding bom-length)
            (detect-unicode-encoding (apply #'octets bytes))
          (expect encoding :to-be expected-encoding)
          (expect bom-length :to-be 0)))))
  (it "does not read past short input or the selected range"
    (dolist (case '((:utf-8 0 ())
                    (:utf-8 0 (0))
                    (:utf-8 0 (#xEF #xBB))
                    (:utf-16be 0 (0 #x41 0))
                    (:utf-32be 0 (0 0 0 #x41))))
      (destructuring-bind (expected-encoding expected-bom-length bytes) case
        (multiple-value-bind (encoding bom-length)
            (detect-unicode-encoding (apply #'octets bytes))
          (expect encoding :to-be expected-encoding)
          (expect bom-length :to-be expected-bom-length))))
    (let ((bytes (octets #x41 #xEF #xBB #xBF #x42)))
      (multiple-value-bind (encoding bom-length)
          (detect-unicode-encoding bytes :start 1 :end 4)
        (expect encoding :to-be :utf-8)
        (expect bom-length :to-be 3))
      (multiple-value-bind (encoding bom-length)
          (detect-unicode-encoding bytes :start 1 :end 3)
        (expect encoding :to-be :utf-8)
        (expect bom-length :to-be 0))))
  (it-property "AUTO round-trips arbitrary UTF-8 strings with a BOM"
      ((values (gen-scalar-string :max #x10FFFF :max-length 24)))
    (let ((bytes (concatenate '(vector (unsigned-byte 8))
                              (octets #xEF #xBB #xBF)
                              (string-to-octets values :encoding :utf-8))))
      (expect (octets-to-string bytes :encoding :auto) :to-equal values)))
  (it-property "AUTO round-trips arbitrary UTF-16BE strings with a BOM"
      ((values (gen-scalar-string :max #x10FFFF :max-length 24)))
    (let ((bytes (concatenate '(vector (unsigned-byte 8))
                              (octets #xFE #xFF)
                              (string-to-octets values :encoding :utf-16be))))
      (expect (octets-to-string bytes :encoding :auto) :to-equal values)))
  (it-property "AUTO round-trips arbitrary UTF-16LE strings with a BOM"
      ((values (gen-scalar-string :max #x10FFFF :max-length 24)))
    (let ((bytes (concatenate '(vector (unsigned-byte 8))
                              (octets #xFF #xFE)
                              (string-to-octets values :encoding :utf-16le))))
      (expect (octets-to-string bytes :encoding :auto) :to-equal values)))
  (it-property "AUTO round-trips arbitrary UTF-32BE strings with a BOM"
      ((values (gen-scalar-string :max #x10FFFF :max-length 24)))
    (let ((bytes (concatenate '(vector (unsigned-byte 8))
                              (octets 0 0 #xFE #xFF)
                              (string-to-octets values :encoding :utf-32be))))
      (expect (octets-to-string bytes :encoding :auto) :to-equal values)))
  (it-property "AUTO round-trips arbitrary UTF-32LE strings with a BOM"
      ((values (gen-scalar-string :max #x10FFFF :max-length 24)))
    (let ((bytes (concatenate '(vector (unsigned-byte 8))
                              (octets #xFF #xFE 0 0)
                              (string-to-octets values :encoding :utf-32le))))
      (expect (octets-to-string bytes :encoding :auto) :to-equal values))))
