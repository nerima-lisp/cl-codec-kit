;;;; t/oracle-test.lisp
;;;;
;;;; Differential testing against SB-EXT:OCTETS-TO-STRING/STRING-TO-OCTETS:
;;;; this library's whole point is not delegating to those functions in its
;;;; shipped system (cl-codec-kit.asd's :DEPENDS-ON stays empty), but nothing
;;;; stops the *test* system from using them as an independent oracle to
;;;; cross-check this library's from-scratch UTF-8 codec against SBCL's own.
;;;; SB-* is an implementation dependency, not an external one -- it does not
;;;; count against DEPENDENCY_POLICY.md's test-only-dependency limit, and it
;;;; never appears outside this one file.
(in-package #:cl-codec-kit/test)

(describe
  "cl-codec-kit vs. SB-EXT, as independent UTF-8 implementations"
  (it-property "STRING-TO-OCTETS agrees with SB-EXT:STRING-TO-OCTETS, for any scalar-value string"
      ((values (gen-scalar-string :max #x10FFFF :min-length 0 :max-length 24)))
    (expect (string-to-octets values :encoding :utf-8)
            :to-equal (sb-ext:string-to-octets values :external-format :utf-8)))

  (it-property "OCTETS-TO-STRING agrees with SB-EXT:OCTETS-TO-STRING, for any valid UTF-8 buffer"
      ((values (gen-scalar-string :max #x10FFFF :min-length 0 :max-length 24)))
    (let ((valid-utf8 (sb-ext:string-to-octets values :external-format :utf-8)))
      (expect (octets-to-string valid-utf8 :encoding :utf-8)
              :to-equal (sb-ext:octets-to-string valid-utf8 :external-format :utf-8)))))
