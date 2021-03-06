
(in-package :om)

;;;===========================
;;; COLLECTION = A SET OF OBJECTS OF A SAME TYPE
;;;===========================

(defclass* collection (named-object)
  ((obj-type :accessor obj-type :initform nil)
   (obj-list :initarg :obj-list :accessor obj-list :initform nil)))

(defmethod get-properties-list ((self collection))
  '(("COLLECTION attibutes"
     (:name "Name" :text name))))

(defmethod homogenize-collection (model list) nil)
                                        
(defmethod om-init-instance ((self collection) &optional args)
  (setf (obj-list self)
        (if (listp (obj-list self)) 
            (om-copy (obj-list self))
          (list (om-copy (obj-list self)))))
  (when (obj-list self)
     ;;; check if all items are of the same type
     (if (list-typep (obj-list self) (type-of (car (obj-list self))))
        (progn 
          (setf (obj-type self) (type-of (car (obj-list self))))
          (homogenize-collection (car (obj-list self)) (obj-list self)))
      (progn
        (om-beep-msg "WARNING: ELEMENTS IN COLLECTION ARE NOT OF THE SAME TYPE!!")
        (setf (obj-type self) nil))))
  self)

;;;===========================
;;; BOX
;;;===========================

(defmethod special-box-p ((name (eql 'collection))) t)

(defmethod omNG-make-new-boxcall ((reference (eql 'collection)) pos &optional init-args)
  (let ((type (and init-args (find-class (car init-args) nil)))
        (val (make-instance 'collection)))
    (when type (setf (obj-type val) (class-name type)))
    (let ((box (omNG-make-new-boxcall (find-class 'collection) pos val)))
      (setf (name box) "...")
      (setf (value (car (inputs box))) (obj-type val))
      box)))

(defmethod objfromobjs ((model symbol) (target collection))
  (if (find-class model nil)
      (setf (obj-type target) model)
    (om-beep-msg "WARNING: CLASS NOT FOUND FOR COLLECTION:" model))
  target)

(defmethod draw-type-of-object ((object collection))
  (string+ (string-upcase (type-of object)) " OF " (string-upcase (obj-type object))))

(defmethod get-object-type-name ((object collection)) 
  (and (obj-type object)
       (string+ "COLLECTION OF " (string-upcase (obj-type object)))))
  

(defmethod display-modes-for-object ((self collection)) '(:hidden :text :mini-view))

(defmethod draw-mini-view ((self collection) (box t) x y w h &optional time)
  (loop for o in (obj-list self) do 
        (set-cache-display box o)
        (draw-mini-view o box x y w h time))) 

;;;===========================
;;; EDITOR
;;;===========================

(defclass collection-editor (OMEditor)
  ((internal-editor :accessor internal-editor :initform nil)
   (current :accessor current :initform 0)
   (show-all :accessor show-all :initform nil)))
 
(defmethod object-has-editor ((self collection)) t)
(defmethod get-editor-class ((self collection)) 'collection-editor)

(defmethod object-value ((self collection-editor))
  (nth (current self) (obj-list (get-value-for-editor (object self)))))

(defmethod get-obj-to-play ((self collection-editor)) (object-value self))

;multidisplay API
(defclass multi-display-editor-mixin ()
  ((multi-display-p :accessor multi-display-p :initarg :multi-display-p :initform nil)
   (multi-obj-list :accessor multi-obj-list :initform nil)))

(defmethod handle-multi-display ((self OMEditor)) nil)
(defmethod handle-multi-display ((self multi-display-editor-mixin)) t)

(defmethod enable-multi-display ((self OMEditor) obj-list) nil)
(defmethod enable-multi-display ((self multi-display-editor-mixin) obj-list) 
  (setf (multi-display-p self) t (multi-obj-list self)  obj-list))

(defmethod disable-multi-display ((self OMEditor)) nil)
(defmethod disable-multi-display ((self multi-display-editor-mixin))
  (setf (multi-display-p self) nil
        (multi-obj-list self)  nil))

(defmethod update-multi-display ((editor collection-editor) t-or-nil)
  (setf (show-all editor) t-or-nil)
  (if t-or-nil
      (enable-multi-display (internal-editor editor) (obj-list (get-value-for-editor (object editor))))
    (disable-multi-display (internal-editor editor)))
  (editor-invalidate-views (internal-editor editor))
  )

(defmethod init-editor ((editor collection-editor)) 
  (let ((collection (get-value-for-editor (object editor))))
    (setf (internal-editor editor) 
          (make-instance (get-editor-class (and (obj-type collection) (nth (current editor) (obj-list collection))))
                         :container-editor editor :object nil))
    ))

(defmethod format-current-text ((editor collection-editor))
  (let ((collection (get-value-for-editor (object editor))))
    (if (obj-list collection)
        (format nil "Current ~A = ~D/~D [~A]" 
                (string-upcase (obj-type collection))
                (1+ (current editor)) (length (obj-list collection))
                (name (nth (current editor) (obj-list collection))))
      "[empty collection]")))

(defmethod editor-invalidate-views ((editor collection-editor))
  (when (internal-editor editor)
    (om-invalidate-view (internal-editor editor))))

(defmethod set-current-text ((editor collection-editor))
  (when (get-g-component editor :current-text)
    (let ((text (format-current-text editor)))
      (om-set-view-size (get-g-component editor :current-text) 
                        (omp (+ 20 (om-string-size text (om-def-font :font1b))) 16))
      (om-set-text (get-g-component editor :current-text) text))))
      
(defmethod update-collection-editor ((editor collection-editor))
  (set-current-text editor)
  (setf (selection (internal-editor editor)) nil)
  (update-default-view (internal-editor editor)) 
  (update-to-editor (internal-editor editor) editor)
  (editor-invalidate-views (internal-editor editor)))
      
(defmethod set-current-next ((editor collection-editor))
  (let ((collection (get-value-for-editor (object editor))))
    (when (obj-list collection)
      (setf (current editor) (mod (1+ (current editor)) (length (obj-list collection))))  
      )))

(defmethod set-current-previous ((editor collection-editor))
  (let ((collection (get-value-for-editor (object editor))))
    (when (obj-list collection)
      (setf (current editor) (mod (1- (current editor)) (length (obj-list collection))))
      )))

(defmethod add-new-and-set-current ((editor collection-editor))
  (let ((collection (get-value-for-editor (object editor))))
    (setf (obj-list collection)
          (append (obj-list collection)
                  (list (initialize-box-initval (make-instance (obj-type collection))))))
    (setf (current editor) (1- (length (obj-list collection))))
    ))

(defmethod remove-and-set-current ((editor collection-editor))
  (let ((collection (get-value-for-editor (object editor))))
    (when (obj-list collection)
      (setf (obj-list collection)
            (remove (nth (current editor) (obj-list collection)) (obj-list collection)))
      (setf (current editor) 
            (max 0 (min (current editor) 
                        (1- (length (obj-list collection))))))
      )))


(defmethod set-window-contents ((editor collection-editor))
  (init-editor editor)
  (when (window editor) 
    (om-remove-subviews (window editor) (main-view editor))
    (om-add-subviews (window editor) 
                     (setf (main-view editor)
                           (make-editor-window-contents editor)))
    (init-editor (internal-editor editor))
    ))

(defmethod update-to-editor ((editor collection-editor) (from t))
  (let ((collection (get-value-for-editor (object editor))))
    (unless (or (null (obj-type collection))
                (equal (type-of (internal-editor editor))
                       (get-editor-class (nth (current editor) (obj-list collection)))))
      (setf (current editor) 0)
      (set-window-contents editor))
    (set-current-text editor)
    (update-to-editor (internal-editor editor) from)
    )
  (call-next-method))

(defmethod make-editor-window-contents ((editor collection-editor))
  (let* ((collection (get-value-for-editor (object editor)))
         (text (format-current-text editor))
         (current-text (om-make-graphic-object 'om-item-text :size (omp (om-string-size text (om-def-font :font1b)) 16) 
                                               :text text :font (om-def-font :font1b)))
         (prev-button (om-make-graphic-object 'om-icon-button 
                                              :size (omp 16 16)
                                              :icon '<- :icon-pushed '<-pushed :icon-disabled '<-disabled
                                              :lock-push nil :enabled (> (length (obj-list collection)) 1)
                                              :action #'(lambda (b)
                                                          (declare (ignore b))
                                                          (set-current-previous editor)
                                                          (update-collection-editor editor))))
         (next-button (om-make-graphic-object 'om-icon-button 
                                              :size (omp 16 16)
                                              :icon '-> :icon-pushed '->pushed :icon-disabled '->disabled
                                              :lock-push nil :enabled (> (length (obj-list collection)) 1)
                                              :action #'(lambda (b)
                                                          (declare (ignore b))
                                                          (set-current-next editor)
                                                          (update-collection-editor editor))))
         (-button (om-make-graphic-object 'om-icon-button 
                                          :size (omp 16 16)
                                          :icon '- :icon-pushed '--pushed :icon-disabled '--disabled
                                          :lock-push nil :enabled (obj-list collection)
                                          :action #'(lambda (b)
                                                      (let ((collection (get-value-for-editor (object editor))))
                                                        (remove-and-set-current editor)
                                                        (when (null (obj-list collection))
                                                          (disable b)
                                                          (setf (current editor) 0)
                                                          (set-window-contents editor))
                                                        (when (<= (length (obj-list collection)) 1)
                                                          (disable prev-button) (disable next-button))
                                                        (update-collection-editor editor)
                                                        (report-modifications editor)
                                                        (update-multi-display editor (show-all editor))
                                                        ))))
         (+button (om-make-graphic-object 'om-icon-button 
                                          :size (omp 16 16)
                                          :icon '+ :icon-pushed '+-pushed :icon-disabled '+-disabled
                                          :lock-push nil :enabled (obj-type (get-value-for-editor (object editor)))
                                          :action #'(lambda (b)
                                                      (declare (ignore b))
                                                      (let* ((collection (get-value-for-editor (object editor)))
                                                             (new? (null (obj-list collection))))
                                                        (add-new-and-set-current editor)
                                                        (when new?
                                                          (enable -button)
                                                          (set-window-contents editor))
                                                        (when (> (length (obj-list collection)) 1)
                                                          (enable prev-button) (enable next-button))
                                                        (update-collection-editor editor)
                                                        (report-modifications editor)
                                                        (update-multi-display editor (show-all editor))
                                                        ))))                                  
         )
    (set-g-component editor :current-text current-text)
    (om-make-layout 
     'om-column-layout 
     :ratios '(1 99)
     :subviews 
     (list 
      (om-make-layout 
       'om-row-layout 
       :subviews 
       (list (om-make-layout 
              'om-row-layout :delta 0 
              :subviews (list prev-button next-button 
                              (om-make-graphic-object 'om-item-view :size (omp 20 20))
                              (when (handle-multi-display (internal-editor editor))
                                     (om-make-di 'om-check-box :text "Show All" :size (omp 80 16) :font (om-def-font :font1)
                                                 :checked-p (show-all editor) :focus nil :default nil
                                                 :di-action #'(lambda (item) 
                                                                (update-multi-display editor (om-checked-p item))
                                                                )
                                                 ))
                               current-text))
             nil
             (om-make-layout 'om-row-layout :delta 0 
                             :subviews 
                             (list +button -button))
             ))
      (make-editor-window-contents (internal-editor editor))))
    ))

;;;=========================
;;; DISPATCH ACTIONS...
;;;=========================
(defmethod editor-key-action ((editor collection-editor) key)
  (cond ((and (om-command-key-p) (equal key :om-key-left))
         (set-current-previous editor)
         (update-collection-editor editor))
        ((and (om-command-key-p) (equal key :om-key-right))
         (set-current-next editor)
         (update-collection-editor editor))
        (t (editor-key-action (internal-editor editor) key))
        ))

(defmethod select-all-command ((self collection-editor))
  #'(lambda () 
      (when (and (internal-editor self) (select-all-command (internal-editor self)))
        (funcall (select-all-command (internal-editor self))))))

(defmethod get-info-command ((self collection-editor)) 
  #'(lambda () 
      (when (and (internal-editor self) (get-info-command (internal-editor self)))
        (funcall (get-info-command (internal-editor self))))))

