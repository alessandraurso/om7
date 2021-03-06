;=========================================================================
; OpenMusic: Visual Programming Language for Music Composition
; PREFERENCES
;=========================================================================

(in-package :om)

(defstruct pref-module (id) (name) (items))
(defstruct pref-item (id) (name)(type) (defval) (doc) (value))

(defun maybe-eval-pref-item-value (pref-item)
  (cond ((and (member (pref-item-type pref-item) '(:folder :file))
              (symbolp (pref-item-value pref-item)))
         (funcall (pref-item-value pref-item)))
        (t (pref-item-value pref-item))))

;;; a list of pref-module
(defvar *user-preferences* nil)

;;;======================================================
;;; MODULES ARE USED TO SORT PREFERENCE ITEMS
(defparameter *pref-order* '(:general :appearance :userlibs :score :conversion :midi :audio :externals))

(defun sort-pref-items (list)
  (sort list #'(lambda (elt1 elt2) 
                 (let ((p1 (position (pref-module-id elt1) *pref-order*))
                       (p2 (position (pref-module-id elt2) *pref-order*)))
                   (or (null p2) (and p1 p2 (<= p1 p2)))))))

(defun find-pref-module (id &optional preferences-list)
   (find id (or preferences-list *user-preferences*) :key 'pref-module-id))

;;; ADD A NEW MODULE WITH NAME
(defun add-preference-module (id name)
  (let ((module (find-pref-module id)))
    (cond (module 
           (om-beep-msg "Warning: Preference module ~A already exists!" id)
           (setf (pref-module-name module) name))
          ((find name *user-preferences* :key 'pref-module-id :test 'string-equal)
           (om-beep-msg "Warning: A preference module with the name '~A' already exists!" name)
           (pushr (make-pref-module :id id :name name) *user-preferences*))
          (t (pushr (make-pref-module :id id :name name) *user-preferences*)))
    (setf *user-preferences* (sort-pref-items *user-preferences*))
    ))

(defun display-om-preferences (&optional module-name)
  (let ((prefs-to-display (if module-name (list (find-pref-module module-name)) *user-preferences*)))
    (om-print "============================")
    (om-print "CURRENT OM PREFERENCES:")
    (om-print "============================")
    (loop for module in prefs-to-display do
          (om-print (format nil "MODULE: ~A" (pref-module-name module)))
          (loop for prefitem in (pref-module-items module) 
                unless (equal (pref-item-type prefitem) :title) do 
                (om-print (format nil "    ~A = ~A" (pref-item-name prefitem) (pref-item-value prefitem))))
          (om-print "============================"))
    ))
; (display-om-preferences)

;;;======================================================
;;; ADD A NEW PREF IN MODULE
(defun add-preference (module-id pref-id name type defval &optional doc)
  (unless (find-pref-module module-id)
    (add-preference-module module-id (string module-id)))
  (let* ((module (find-pref-module module-id))
         (pref-item (find pref-id (pref-module-items module) :key 'pref-item-id)))
    (if pref-item 
        ;; the pref already exist (e.g. it was already loaded when this function s called):
        ;; we update its name, defval etc. but keep the value
        ;(om-print "Warning: A preference with the same ID '~A' already exists!" pref-id)
        (setf (pref-item-name pref-item) name 
              (pref-item-type pref-item) type
              (pref-item-defval pref-item) defval 
              (pref-item-doc pref-item) doc)
      (setf (pref-module-items module)
            (append (pref-module-items module)
                    (list (make-pref-item :id pref-id :name name :type type :defval defval :doc doc :value defval)))))))
    
;;; hack
;;; todo: check that this section does not already exist
(defun add-preference-section (module-id name)
  (let* ((module (find-pref-module module-id))) 
    (unless (find name (remove-if-not 
                        #'(lambda (item) (equal (pref-item-id item) :title)) 
                        (pref-module-items module))
                  :test 'string-equal :key 'pref-item-name)
      (setf (pref-module-items module)
            (append (pref-module-items module)
                    (list (make-pref-item :id :title :name name :type :title)))))))

;;;======================================================
;;; GET THE PREFERENCE VALUES
(defun get-pref-in-module (module pref-id)
  (find pref-id (pref-module-items module) :key 'pref-item-id))

(defun get-pref (module-name pref-key &optional preferences-list)
  (let ((module (find-pref-module module-name preferences-list)))
    (when module 
      (get-pref-in-module module pref-key))))

(defun get-pref-value (module-name pref-key &optional preferences-list)
  (let ((pref-item (get-pref module-name pref-key preferences-list)))
    (if pref-item
        (maybe-eval-pref-item-value pref-item)
      (om-beep-msg "Preference '~A' not found in module '~A'" pref-key module-name))))

(defun restore-default-preferences (&optional pref-module-id)
  (loop for module in *user-preferences*
        when (or (not pref-module-id) (equal pref-module-id (pref-module-id module)))
        do (loop for pref in (pref-module-items module) do
              (setf (pref-item-value pref) (pref-item-defval pref)))))

;;;======================================================  
;;; SET THE PREFERENCE VALUES
(defmethod set-pref-in-module (module key val)
  (let ((pref-item (get-pref-in-module module key)))
    (if pref-item 
        (setf (pref-item-value pref-item) val)
      (add-preference (pref-module-id module) key (string key) NIL val))))

(defun set-pref (module-name key val &optional preferences-list)
  (set-pref-in-module (find-pref-module module-name preferences-list) key val))

;;;======================================================
;;; PREFERENCES ARE SAVED AS
;;; (:preferences
;;;   (:MODULE-NAME1 (:PREF1 val1) (:PREF-2 VAL2) ...))
;;;   (:MODULE-NAME2 (:PREF1 val1) (:PREF-2 VAL2) ...))
;;;   ... )
;;;======================================================
; (save-preferences)
(defun save-pref-module (module)
  (cons (pref-module-id module)
        (loop for pref in (pref-module-items module) 
              unless (equal :title (pref-item-id pref))
              collect
              (list (pref-item-id pref) (omng-save (pref-item-value pref))))))

(defun save-preferences ()
  (if *current-workSpace*
      (save-workspace-file *current-workSpace*)
    (save-om-preferences)))

(defun load-saved-prefs (saved-prefs)
  (loop for saved-module in saved-prefs do
        ;;; find  the corresponding pref module in OM prefs
        (let* ((module-id (car saved-module))
               (real-module (find-pref-module module-id)))
          (when real-module
            (loop for pref in (cdr saved-module)
                  do (set-pref module-id (car pref) (omng-load (cadr pref)))))
          )))

(add-om-exit-action 'save-preferences)

;;;====================================
;;; DEFAULT MODULE
;;;====================================

(add-preference-module :general "General")
(add-preference :general :user-name "User name" :string "me")

;;; special case: sets a behavior from the OM-API
;(defmethod set-pref-in-module :after ((module (eql :general)) (key (:eql :listener-on-top)) val) (setf om-lisp::*listener-on-top* val))
;;; not anymore (initarg in the constructor)







