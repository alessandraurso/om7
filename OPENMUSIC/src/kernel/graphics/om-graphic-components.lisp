(in-package :om)


;===========================
; Simple horizontal bar 
;===========================

(defclass bar-item (om-item-view) 
  ((fg-color :accessor fg-color :initarg :fg-color :initform (om-def-color :black))
   (thick :accessor thick :initarg :thick :initform 1)))

(defmethod om-draw-contents ((self bar-item))
  (call-next-method)
  (om-with-line-size (thick self)
    (om-with-fg-color (fg-color self)
      (om-draw-line 0 0 (w self) 0))))

;===========================
; Just a picture
;===========================

(defclass picture-view (om-item-view)
   ((pict :initform nil :initarg :pict :accessor pict)))

(defmethod om-draw-contents ((self picture-view))
   (call-next-method)
   (when (pict self)
     (om-draw-picture self 
                      (pict self) (om-make-point 0 0) 
                      (om-make-point (w self) (h self)))))

;;;=====================
;;; 3D-border view
;;;=====================

(defclass 3Dborder-view (om-view)
  ((c+ :accessor c+ :initform (om-make-color 0.835 0.835 0.843) :initarg :c+)
   (c++ :accessor c++ :initform (om-make-color 0.87 0.87 0.88) :initarg :c++)
   (c- :accessor c- :initform (om-make-color 0.604 0.604 0.604) :initarg :c-)
   (c-- :accessor c-- :initform (om-make-color 0.514 0.514 0.514) :initarg :c--)))

(defmethod om-draw-contents ((self 3Dborder-view))
  (call-next-method)
  (let ((x (om-h-scroll-position self))
        (y (om-v-scroll-position self))
        (w (om-point-x (om-interior-size self)))
        (h (om-point-y (om-interior-size self))))
    (draw-3D-border self x y (+ x w) (+ y h))))

(defun draw-3D-border (self x y xx yy)
  (om-with-fg-color self (c++ self)
    (om-draw-line (+ x 1) y (- xx 1) y) 
    (om-draw-line x (+ y 1) x (- yy 1)))
  (om-with-fg-color self (c+ self)
    (om-draw-line (+ x 2) (+ y 1) (- xx 2) (+ y 1)) 
    (om-draw-line (+ x 1) (+ y 2) (+ x 1) (- yy 2)))
  (om-with-fg-color self (c-- self)
    (om-draw-line (+ x 1) (- yy 1) (- xx 1) (- yy 1)) 
    (om-draw-line (- xx 1) (+ y 1) (- xx 1) (- yy 1)))
  (om-with-fg-color self (c- self)
    (om-draw-line (+ x 2) (- yy 2) (- xx 2) (- yy 2)) 
    (om-draw-line (- xx 2) (+ y 2) (- xx 2) (- yy 2))))



;==========================================================
; custom button with pict in "resources/di/"
;==========================================================
 
;(let ((win (om-make-window 'om-window))
;      (v (om-make-view 'om-view :size (om-make-point 500 500)))
;      (but (om-make-graphic-object 'om-icon-button :icon 'but :icon-pushed 'but-pushed :lock-push t)))
;  (om-add-subviews win v)
;  (om-add-subviews v but)
;  win)

(defclass om-icon-button (om-item-view)
  ((icon :initform nil :accessor icon :initarg :icon)
   (icon-pushed :initform nil :accessor icon-pushed :initarg :icon-pushed)
   (icon-disabled :initform nil :accessor icon-disabled :initarg :icon-disabled)
   (id :initform nil :accessor id :initarg :id)
   (action :initform nil :accessor action :initarg :action)
   (lock-push :initform nil :accessor lock-push :initarg :lock-push)
   (pushed :initform nil :accessor pushed :initarg :pushed)
   (enabled :initform t :accessor enabled :initarg :enabled)
   (text :initform nil :accessor text :initarg :text)
   (fg-color :initform nil :accessor fg-color :initarg :fg-color)
   (font :initform nil :accessor font :initarg :font)))
             
(defmethod om-set-fg-color ((self om-icon-button) color)
  (setf (fg-color self) color)
  (om-invalidate-view self))

(defmethod select ((self om-icon-button))
  (setf (pushed self) t)
  (om-invalidate-view self))

(defmethod unselect ((self om-icon-button))
  (setf (pushed self) nil)
  (om-invalidate-view self))

(defmethod enable ((self om-icon-button))
  (setf (enabled self) t)
  (om-invalidate-view self))

(defmethod disable ((self om-icon-button))
  (setf (enabled self) nil)
  (om-invalidate-view self))

(defmethod om-view-doubleclick-handler ((self om-icon-button) where)
  (om-view-click-handler self where))
 
(defmethod om-view-click-handler ((self om-icon-button) where)
   "this function call the slot action of SELF with the parameter SELF"
   (declare (ignore where))
   (when (enabled self)
     (if (lock-push self) 
         (setf (pushed self) (not (pushed self)))
       (setf (pushed self) t))
     (om-invalidate-view self)))

(defmethod om-click-release-handler ((self om-icon-button) where)
  (when (and (enabled self) (action self))
    (om-with-error-handle
      (apply (action self) (list self))))
  (unless (lock-push self) (setf (pushed self) nil))
  (om-invalidate-view self))

(defmethod om-draw-contents ((self om-icon-button))
   (call-next-method)
   (let* ((icn (or (and (pushed self) (icon-pushed self))
                   (and (not (enabled self)) (icon-disabled self))
                   (icon self))))
     (om-draw-picture icn :w (w self) :h (h self)))
   (when (text self)
     (let* ((ff (or (font self) (om-def-font :font1)))
            (cc (or (fg-color self) (om-def-color :black)))
            (wh (values-list (om-string-size (text self) ff)))
            (yy (round (+ (- (cadr wh) (if (pushed self) 5 6)) (h self)) 2))
            (xx (max 0 (- (round (w self) 2) (ceiling (car wh) 2)))))
       (om-with-fg-color self cc
         (om-with-font ff
                       (om-draw-string xx yy (text self))))))
   (when (and (lock-push self) (pushed self) (not (icon-pushed self)))
     (om-draw-rect 0 0 (w self) (h self) :fill t :color (om-make-color-alpha (om-def-color :black) 0.5))))


;==========================================================
; custom view to pick a color
;==========================================================

(defclass color-view (om-view)
  ((color :accessor color :initarg :color :initform (om-make-color 0 0 0))
   (after-fun :accessor after-fun :initform nil :initarg :after-fun)
   (enabled :accessor enabled :initform t :initarg :enabled)
   (border :accessor border :initform t :initarg :border)))

(defmethod om-draw-contents ((self color-view))
  (om-draw-rect 0 0 (om-width self) (om-height self) :color (or (color self) (om-def-color :gray)) :fill (color self))
  (when (not (enabled self))
    (om-draw-rect 0 0 (om-width self) (om-height self) 
                  :color (om-make-color-alpha (om-def-color :white) 0.5) 
                  :fill t))
  (when (border self)
    (om-draw-rect 0 0 (om-width self) (om-height self) 
                  :color (om-def-color :gray)
                  :fill nil)))

(defmethod om-view-click-handler ((self color-view) pos)
  (declare (ignore pos))
  (when (enabled self)
    (let ((color (om-choose-color-dialog :color (color self) :owner self)))
      (when color (setf (color self) color)
        (om-invalidate-view self)
        (when (after-fun self) (funcall (after-fun self) self))))))


;==========================================================
; custom view to change a text
;==========================================================

(defclass click-and-edit-text (om-view)
  ((text :accessor text :initform "" :initarg :text)
   (after-fun :accessor after-fun :initform nil :initarg :after-fun)
   (enabled :accessor enabled :initform t :initarg :enabled)
   (border :accessor border :initform t :initarg :border))
  (:default-initargs :resize-callback nil))

(defmethod om-draw-contents ((self click-and-edit-text))
  (when (border self) 
    (om-with-fg-color (border self) 
      (om-draw-rect 0 0 (om-width self) (om-height self))))
  (om-with-fg-color (om-get-fg-color self) 
    (om-with-font (om-def-font :font2)
    ;(if (enabled self) (om-def-color :black) (om-def-color :gray))
    (om-draw-string 0 14 (text self)))))

(defmethod om-view-click-handler ((self click-and-edit-text) pos)
  (declare (ignore pos))
  (when (enabled self)
    (let ((txt (om-get-user-string "" :initial-string (text self))))
      (when txt (setf (text self) txt)
        (om-invalidate-view self)
        (when (after-fun self) (funcall (after-fun self) self))))))


;==============
; NUMBOX
;==============

(defclass numbox (om-item-text)
  ((value   :initform 0     :initarg :value   :accessor value)
   (min-val :initform 0     :initarg :min-val :accessor min-val)
   (max-val :initform 30000 :initarg :max-val :accessor max-val)
   (enabled :initform t :initarg :enabled :accessor enabled)
   (change-fun :initform nil :initarg :change-fun :accessor change-fun)
   (after-fun :initform nil :initarg :after-fun :accessor after-fun))
  (:default-initargs :border t))

(defmethod om-view-cursor ((self numbox)) (om-get-cursor :v-size))

(defmethod initialize-instance :after ((self numbox) &rest args) 
  ;(om-set-dialog-item-text self (format nil " ~D" (value self)))
  (om-set-text self (format nil " ~D" (value self))))

(defmethod set-value ((self numbox) value)
   (setf (value self) value)
   (om-set-text self (format () " ~S" value))
   (om-invalidate-view self))

(defmethod enable-numbox ((self numbox) t-or-nil)
 (setf (enabled self) t-or-nil)
 (om-set-fg-color self (if (enable self) (om-def-color :black) (om-def-color :gray))))

(defmethod map-mouse-increment ((self numbox))
  (cond ((om-shift-key-p) 10) 
        ((om-command-key-p) 100)
        (t 0.5)))

(defmethod om-view-click-handler  ((self numbox) where)
  (when (enabled self)
    (let ((start-y (om-point-y where))
          (start-v (value self)))
      (om-init-temp-graphics-motion self where NIL
                                    :motion #'(lambda (view position)
                                                (let* ((inc (- start-y (om-point-y position)))
                                                       (new-val (+ start-v (* (map-mouse-increment self) inc))))
                                                  (when (and (>= new-val (min-val self))
                                                             (<= new-val (max-val self)))
                                                    (set-value self (round new-val))
                                                    (when (and (change-fun self) (not (= (round new-val) start-v)))
                                                      (funcall (change-fun self) self)))))
                                    :release #'(lambda (view position) (when (after-fun self) (funcall (after-fun self) self)))))))


