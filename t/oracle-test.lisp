(in-package #:cl-codec-kit/test)

(describe
  "cl-codec-kit vs. SB-EXT, as independent UTF-8 implementations"
  (it-property "STRING-TO-OCTETS agrees with SB-EXT:STRING-TO-OCTETS, for any scalar-value string"
      ((values (gen-scalar-string :max #x10FFFF :min-length 0 :max-length 24)))
    (expect (string-to-octets values :encoding :utf-8)
            :to-equalp (sb-ext:string-to-octets values :external-format :utf-8)))

  (it-property "OCTETS-TO-STRING agrees with SB-EXT:OCTETS-TO-STRING, for any valid UTF-8 buffer"
      ((values (gen-scalar-string :max #x10FFFF :min-length 0 :max-length 24)))
    (let ((valid-utf8 (sb-ext:string-to-octets values :external-format :utf-8)))
      (expect (octets-to-string valid-utf8 :encoding :utf-8)
              :to-equal (sb-ext:octets-to-string valid-utf8 :external-format :utf-8)))))
