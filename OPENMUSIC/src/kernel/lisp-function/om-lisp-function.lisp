(in-package :om)

(defclass OMLispFunction (OMProgrammingObject) 
  ((text :initarg :text :initform "" :accessor text)))

(defclass OMLispFunctionInternal (OMLispFunction) ()
  (:default-initargs :icon 'lisp-f)
  (:metaclass omstandardclass))

(defmethod window-name-from-object ((self OMLispFunctionInternal))
  (format nil "~A  [~A]" (name self) "internal Lisp function"))

(defclass OMLispFunctionFile (OMPersistantObject OMLispFunction) ()
  (:default-initargs :icon 'lisp-f-file) 
  (:metaclass omstandardclass))

(defparameter *default-lisp-function-text* 
  '(";;; Edit a valid LAMBDA EXPRESSION"
    ";;; e.g. (lambda (arg1 arg2 ...) ( ... ))"
    "(lambda () (om-beep))"))

(defmethod make-new-om-doc ((type (eql :lispfun)) name)
  (make-instance 'OMLispFunctionFile 
                 :name name
                 :text *default-lisp-function-text*))

(defmethod special-box-p ((name (eql 'lisp))) t)

(defclass OMBoxLisp (OMBoxAbstraction) ())
(defmethod get-box-class ((self OMLispFunction)) 'OMBoxLisp)

(defmethod omNG-make-new-boxcall ((reference (eql 'lisp)) pos &optional init-args)
  (omNG-make-new-boxcall 
   (make-instance 'OMLispFunctionInternal
                  :name (if init-args (format nil "~A" (car (list! init-args))) "my-function")
                  :text *default-lisp-function-text*)
   pos init-args))


(defmethod draw-patch-icon :after ((self OMBoxLisp))
  (unless (compiled? (reference self))
    (om-with-fg-color (om-def-color :dark-red)
      (om-with-font (om-make-font "Times" 16 :style '(:bold))
        (om-draw-string 2 (- (box-h self) 8) "Error !!")))))


(defmethod decapsulable ((self OMLispFunction)) nil)

(defmethod inputs ((self OMLispFunction)) 
  (compile-if-needed self)
  (let ((fname (intern (string (compiled-fun-name self)) :om)))
    (when (fboundp fname) 
      (let ((args (function-arg-list fname)))
        (loop for a in args 
              for i from 0 collect 
          (let ((in (make-instance 'OMIn :name (string a))))
            (setf (index in) i)
            in)))
      )))

(defmethod outputs ((self OMLispFunction)) 
  (compile-if-needed self)
  (let ((namelist '("out")))
    (loop for n in namelist 
          for i from 0 collect 
          (let ((o (make-instance 'OMOut :name n)))
            (setf (index o) i)
            o))
    ))

(defmethod update-lisp-fun ((self OMLispFunction) text) 
  (setf (text self) text)
  (compile-patch self)
  (loop for item in (references-to self) do
        (update-from-reference item)))


(defmethod compile-patch ((self OMLispFunction)) 
  "Compilation of a lisp function"
  (handler-bind 
      ((error #'(lambda (err)
                  (om-beep-msg "An error of type ~a occurred: ~a" (type-of err) (format nil "~A" err))
                  (setf (compiled? self) nil)
                  (abort err)
                  )))
    
    (let* ((lambda-expression (read-from-string 
                               (reduce #'(lambda (s1 s2) (concatenate 'string s1 (string #\Newline) s2))
                                       (text self))
                               nil))
           (function-def
            (if (and lambda-expression (lambda-expression-p lambda-expression))
                (progn (setf (compiled? self) t)
                  `(defun ,(intern (string (compiled-fun-name self)) :om) 
                          ,.(cdr lambda-expression)))
              (progn (om-beep-msg "ERROR IN LAMBDA EXPRESSION!!")
                `(defun ,(intern (string (compiled-fun-name self)) :om) () nil)))))
      (compile (eval function-def))
      ;(setf (compiled? self) t)
      )
    ))

;;;===================
;;; EDITOR
;;;===================

(defclass lisp-function-editor (OMDocumentEditor) ())
(defmethod get-editor-class ((self OMLispFunction)) 'lisp-function-editor)

;;; nothing, e.g. to close when the editor is closed
(defmethod close-internal-elements ((self OMLispFunction)) nil)

(defmethod save-command ((self lisp-function-editor))
  #'(lambda () 
      (let ((doc-to-save (if (is-persistant (object self)) 
                               (object self)
                             (find-persistant-container (object self)))))
        (if doc-to-save
            (progn 
                (save-document doc-to-save)
                (update-window-name self))
            (om-beep-msg "No document to save !!!"))
          )))


(defclass lisp-function-editor-window (om-lisp::om-text-editor-window) 
  ((editor :initarg :editor :initform nil :accessor editor)))

(defmethod om-lisp::save-operation-enabled ((self lisp-function-editor-window)) 
  (is-persistant (object (editor self)))) 

(defmethod open-editor-window ((self lisp-function-editor))
  (if (and (window self) (om-window-open-p (window self)))
      (om-select-window (window self))
    (let* ((lispf (object self))
           (edwin (om-lisp::om-open-text-editor 
                   :contents (text lispf)
                   :lisp t
                   :class 'lisp-function-editor-window
                   :title (window-name-from-object lispf))
                  ))
      (setf (editor edwin) self)
      (setf (window self) edwin)
      edwin)))


(defmethod om-lisp::om-text-editor-modified ((self lisp-function-editor-window))
  (report-modifications (editor self))
  (call-next-method))

(defmethod om-lisp::update-window-title ((self lisp-function-editor-window) &optional (modified nil modified-supplied-p))
  (om-lisp::om-text-editor-window-set-title self (window-name-from-object (object (editor self)))))

(defmethod om-lisp::om-text-editor-destroy-callback ((win lisp-function-editor-window))
  (editor-close (editor win))
  (update-lisp-fun (object (editor win))
                   (om-lisp::om-get-text-editor-text win))
  (setf (window (editor win)) nil)
  (setf (g-components (editor win)) nil)
  (call-next-method))

(defmethod om-lisp::om-text-editor-activate-callback ((win lisp-function-editor-window) activate)
  (when (editor win) 
    (when (equal activate nil)
      (update-lisp-fun (object (editor win))
                       (om-lisp::om-get-text-editor-text win)))))

(defmethod om-lisp::type-filter-for-text-editor ((self lisp-function-editor-window)) 
  '("OM Lisp function" "*.olsp"))

(defmethod om-lisp::text-editor-window-menus ((self lisp-function-editor-window)) (om-menu-items (editor self)))

