(in-package :om-fi)

;;; VERY IMPORTANT OTHERWISE ALL SDIF-WRITE CRASH OM !!!

;; redefinitions using CFFI
;; previously cffi::%mem-set
(defun om-write-ptr (ptr pos type value) 
  (cffi::mem-set value ptr type pos))

;; previously cffi::%mem-ref
;; previously cffi::mem-ref
(defun om-read-ptr (ptr pos type) 
  (cffi::mem-aref ptr type pos))
 
;(setf aaa (om-make-pointer 5))
;(om-write-ptr aaa 1 :float 8.0)
;(om-read-ptr aaa 0 :float)
