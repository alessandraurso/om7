(in-package :om)


;;;=================================
;;; AN EDITOR ASSOCIATED WITH A PLAYER
;;;=================================

(defclass play-editor-mixin ()
   ((player :initform nil :accessor player)
    (player-type :initform nil :accessor player-type)
    (loop-play :initform nil :accessor loop-play)
    (play-interval :initform nil :accessor play-interval)
    (end-callback :initform nil :accessor end-callback)
    (player-specific-controls :initform nil :accessor player-specific-controls)
    ;;=====
    (play-button :initform nil :accessor play-button)
    (pause-button :initform nil :accessor pause-button)
    (stop-button :initform nil :accessor stop-button)
    (time-monitor :initform nil :accessor time-monitor)
    (rec-button :initform nil :accessor rec-button)
    (repeat-button :initform nil :accessor repeat-button)
    (next-button :initform nil :accessor next-button)
    (prev-button :initform nil :accessor prev-button)
    ;;=====
    (metronome :initform nil :initarg :metronome :accessor metronome :type metronome)
    (metronome-on :initform nil :type boolean)
    ;;=====
    (tempo-box :initform nil :accessor tempo-box)
    (signature-box :initform nil :accessor signature-box)))

(defmethod editor-make-player ((self play-editor-mixin))
  (make-player :reactive-player; :dynamic-scheduler 
               :run-callback 'play-editor-callback
               :stop-callback 'stop-editor-callback))

(defmethod initialize-instance :after ((self play-editor-mixin) &rest initargs)
  (setf (player self) (editor-make-player self))
  (when (find-om-package "metronome")
    (setf (metronome self) (make-instance 'metronome :editor self))))

(defmethod editor-close ((self play-editor-mixin))
  (editor-stop self)
  (call-next-method))

;;; A REDEFINIR PAR LES SOUS-CLASSES
(defmethod cursor-panes ((self play-editor-mixin)) nil)


;;;=====================================
;;; HELPERS TO SEND DATA TO THE PLAYER:
;;;=====================================

(defmethod get-player-engine ((self play-editor-mixin)) nil)

(defmethod get-obj-to-play ((self play-editor-mixin)) nil)

(defmethod get-play-duration ((self play-editor-mixin)) 
  (+ (get-obj-dur (get-obj-to-play self)) 100))  ;;; = 0 if obj = NIL

;; priorit� sur le mode
; (equal (cursor-mode selection-pane) :interval)
(defmethod play-selection-first ((self t)) t)

(defmethod get-interval-to-play ((self play-editor-mixin))
  (when (and (play-selection-first self) 
             (play-interval self)
             (get-obj-to-play self))
    (if (= (car (play-interval self)) (cadr (play-interval self)))
        (when (plusp (car (play-interval self)))
          (list (car (play-interval self)) most-positive-fixnum ))
      (play-interval self))))


(defmethod start-interval-selection ((self play-editor-mixin) view pos)
  (let ((t1 (round (pix-to-x view (om-point-x pos)))))
    (om-init-temp-graphics-motion 
     view pos nil
     :motion #'(lambda (view p2)
                 (let ((t2 (round (pix-to-x view (om-point-x p2)))))
                   (editor-set-interval self (list (min t1 t2) (max t1 t2)))))
     :release #'(lambda (view pos) 
                  (om-invalidate-view (window self)))
     :min-move 10)))

(defmethod change-interval-begin ((self play-editor-mixin) view pos)
  (om-init-temp-graphics-motion 
   view pos nil
   :motion #'(lambda (view p)
               (let ((t1 (round (pix-to-x view (om-point-x p)))))
                 (editor-set-interval self (list t1 (cadr (play-interval self))))))
   :release #'(lambda (view pos) 
                (om-invalidate-view (window self)))
   :min-move 4))

(defmethod change-interval-end ((self play-editor-mixin) view pos)
  (om-init-temp-graphics-motion 
   view pos nil
   :motion #'(lambda (view p)
               (let ((t2 (round (pix-to-x view (om-point-x p)))))
                 (editor-set-interval self (list (car (play-interval self)) t2))))
   :release #'(lambda (view pos) 
                (om-invalidate-view (window self)))
   :min-move 4))

(defmethod editor-fix-interval ((self play-editor-mixin) interval &key (high-bound nil))
  (list (max 0 (car interval)) (if high-bound
                                   (min (get-obj-dur (get-obj-to-play self)) (cadr interval))
                                 (cadr interval))))

(defmethod editor-set-interval ((self t) interval) nil)

(defmethod editor-set-interval ((self play-editor-mixin) interval)
  (let ((inter (editor-fix-interval self interval)))
    (setf (play-interval self) inter)
    (set-object-interval (get-obj-to-play self) inter)
    (mapcar #'(lambda (p) 
                (setf (cursor-interval p) inter)
                (om-invalidate-view p))
            (cursor-panes self))))


(defmethod editor-reset-interval ((self play-editor-mixin))
  (editor-set-interval self '(0 0))
  (mapcar 'reset-cursor (cursor-panes self)))

(defmethod set-cursor-time ((self play-editor-mixin) time)
  (mapcar #'(lambda (pane) (update-cursor pane time)) (cursor-panes self))
  (editor-invalidate-views self))

(defmethod additional-player-params ((self t)) nil)

;;; return the views to update
(defmethod play-editor-get-ruler-views ((self play-editor-mixin)) nil)
  
(defmethod reinit-x-ranges ((self play-editor-mixin))
  (let ((play-obj (get-obj-to-play self)))
    (mapcar #'(lambda (ruler-view)
                (if play-obj
                    (set-ruler-range ruler-view 0 (+ (get-obj-dur play-obj) 1000))
                  (set-ruler-range ruler-view (vmin self) (or (vmax self) 1000))))
            (list! (play-editor-get-ruler-views self)))))

(defmethod reinit-x-ranges-from-ruler ((self play-editor-mixin)) 
  (reinit-x-ranges self))

;;;=================================
;;; PLAYER CALLS
;;;=================================

(defmethod play-editor-callback ((self play-editor-mixin) time)
  (set-time-display self time)
  (mapcar #'(lambda (view) (when view (update-cursor view time))) (cursor-panes self)))

;;; never used..
(defmethod editor-callback-fun ((self play-editor-mixin))
  #'(lambda (editor time)
      (handler-bind ((error #'(lambda (e) 
                                (print e)
                                (om-kill-process (callback-process (player self)))
                                (abort e))))
        (play-editor-callback editor time))))

(defmethod editor-play ((self play-editor-mixin))
  (when (play-obj? (get-obj-to-play self))
    (when (pause-button self) (unselect (pause-button self)))
    (when (play-button self) (select (play-button self)))
    (if (equal (player-get-object-state (player self) (get-obj-to-play self)) :pause)
        (progn
          (player-continue-object (player self) (get-obj-to-play self) )
          (if (and (metronome self) (metronome-on self)) (player-continue-object (player self) (metronome self))))
      (let ((interval (get-interval-to-play self)))
        (mapcar #'(lambda (view) (start-cursor view)) (cursor-panes self))
        (if (and (metronome self) (metronome-on self)) (player-play-object (player self) (metronome self) nil :interval interval))
        (player-play-object (player self) (get-obj-to-play self) self :interval interval)
        (player-start (player self) :start-t (or (car interval) 0) :end-t (cadr interval))))))

(defmethod editor-pause ((self play-editor-mixin))
  (let ((ti (om-get-internal-time)))
    (when (play-button self) (unselect (play-button self)))
    (when (pause-button self) (select (pause-button self)))
    (if (and (metronome self) (metronome-on self))
        (player-pause-object (player self) (metronome self)))
    (player-pause-object (player self) (get-obj-to-play self))))

(defmethod editor-stop ((self play-editor-mixin))
  (when (play-button self) (unselect (play-button self)))
  (when (pause-button self) (unselect (pause-button self)))
  ;(if (equal (state (player self)) :record) (editor-stop-record self))
  (mapcar #'(lambda (view) (stop-cursor view)) (cursor-panes self))
  (player-stop-object (player self) (get-obj-to-play self))
  (if (and (metronome self) (metronome-on self)) (player-stop-object (player self) (metronome self)))
  (set-time-display self 0)
  (mapcar 'reset-cursor (cursor-panes self)))

(defmethod editor-play/stop ((self play-editor-mixin))
  (if (not (eq (player-get-object-state (player self) (get-obj-to-play self)) :stop))
      (editor-stop self)
    (editor-play self)))

(defmethod editor-play/pause ((self play-editor-mixin))
  (if (not (eq (player-get-object-state (player self) (get-obj-to-play self)) :play))
      (editor-play self)
    (editor-pause self)))

(defmethod stop-editor-callback ((self play-editor-mixin)) 
  ;(mapcar #'(lambda (view) (stop-cursor view)) (cursor-panes self))
  (when (play-button self) (unselect (play-button self)))
  (when (pause-button self) (unselect (pause-button self))))

(defmethod editor-record ((self play-editor-mixin))
  ;;;(setf (engines (player self)) (list (get-player-engine self)))
  ;(player-record (player self))
  nil)

;;; FUNCTIONS TO DEFINE BY THE EDITORS
(defmethod editor-next-step ((self play-editor-mixin)) nil)
(defmethod editor-previous-step ((self play-editor-mixin)) nil)
(defmethod editor-repeat ((self play-editor-mixin) t-or-nil) nil)


;;;===================================
; VIEW WITH CURSOR
;;;===================================

(defclass x-cursor-graduated-view (x-graduated-view om-transient-drawing-view) 
  ((cursor-mode  :initform :normal :accessor cursor-mode :initarg :cursor-mode)   ;; :normal ou :interval
   (cursor-interval :initform '(0 0) :accessor cursor-interval)
   ;(cursor :accessor cursor :initform nil)
   (cursor-pos :initform 0 :accessor cursor-pos))
  (:default-initargs :fit-size-to-children nil))


;(defclass cursor-line (om-item-line) ())
;(defmethod om-view-click-handler ((self cursor-line) pos)
;  (om-view-click-handler (om-view-container self) (om-convert-coordinates pos self (om-view-container self))))

(defmethod draw-cursor-line ((self x-cursor-graduated-view) position size)
  (om-with-line-size 2
    (om-with-fg-color (om-make-color 0.8 0.5 0.5)
      (om-draw-line (om-point-x position) (om-point-y position)
                    (om-point-x position)
                    (+ (om-point-y position) (om-point-y size))))))

#|
(defmethod om-view-click-handler ((self cursor-line) position) 
  (let* ((container (om-view-container self))
         (editor (editor (om-view-window container))))
    (when container
      (unless (om-view-click-handler container (om-view-position self))
        (let ((time (pix-to-x container (om-point-x (om-view-position self)))))
          (om-init-temp-graphics-motion 
           container position nil 
           :min-move 4
           :motion #'(lambda (view pos)
                       (let* ((new-t (round (dpix-to-dx container (- (om-point-x pos) (om-point-x position))))))
                         (set-cursor-time editor new-t)))
           :release #'(lambda (view pos)
                        (let* ((new-t (round (dpix-to-dx container (- (om-point-x pos) (om-point-x position))))))
                         (set-cursor-time editor new-t)
                         (if (or (null (play-interval editor))
                                 (= (car (play-interval editor)) (cadr (play-interval editor))))
                             (editor-set-interval editor (list new-t new-t)))
                         ))))))))
|#


(defmethod move-time-point-action ((view x-cursor-graduated-view) editor orig-point position)
  (let* ((time (pix-to-x view (om-point-x position))))
    (om-init-temp-graphics-motion 
     view position nil :min-move 4
     :motion #'(lambda (view pos)
                 (let* ((tmp_time (pixel-to-time view (om-point-x pos)))
                        (dt (round (- tmp_time time)))
                        (selected-point-time (item-get-internal-time orig-point)))
                   (set-time-display editor tmp_time)
                   (when (selection editor) 

                     (let* ((new-dt  (if (snap-to-grid editor) (adapt-dt-for-grid-and-markers (time-ruler editor) selected-point-time dt) dt)))
                       (when (not (equal new-dt 0))
                         (setf time (+ time new-dt))
                         (translate-selection editor new-dt)
                         ))
                     (update-to-editor (container-editor editor) editor)))))))


;(defmethod make-view-cursor ((self x-cursor-graduated-view)) 
;  (om-make-graphic-object 'cursor-line 
;                          :position (omp (time-to-pixel self (car (cursor-interval self))) 0) 
;                          :size (omp 2 (h self))
;                          :fg-color (om-make-color 0.9 0.45 0.45) 
;                          :accepts-focus-p nil))

;(defmethod update-cursor-pos ((self x-cursor-graduated-view))
;  (when (cursor self)
;    (om-set-view-position (cursor self) (omp (time-to-pixel self (cursor-pos self)) 0))))


;(defmethod start-cursor ((self x-cursor-graduated-view)) 
;  (unless (cursor self)
;    (setf (cursor self) (make-view-cursor self))
;    (om-add-subviews self (cursor self))))
(defmethod start-cursor ((self x-cursor-graduated-view)) 
  (om-stop-transient-drawing self)
  (om-start-transient-drawing
   self #'draw-cursor-line
   (omp (time-to-pixel self (car (cursor-interval self))) 0)
   (omp 2 (h self))))


;(defmethod stop-cursor ((self x-cursor-graduated-view))
;  (when (cursor self)
;    (om-remove-subviews self (cursor self))
;    (setf (cursor self) nil)))
(defmethod stop-cursor ((self x-cursor-graduated-view))
  (om-stop-transient-drawing self)) 
              
(defmethod reset-cursor ((self x-cursor-graduated-view))
  (setf (cursor-pos self) (or (car (cursor-interval self)) 0))
  (om-invalidate-view self))


;(defmethod om-view-resized :after ((self x-cursor-graduated-view) size)
;  (when (cursor self)
;    (om-set-view-size (cursor self) (omp 1 (om-point-y size)))
;    (om-set-view-position (cursor self) (omp (time-to-pixel self (cursor-pos self)) 0))))
(defmethod om-view-resized :after ((self x-cursor-graduated-view) size) 
  (om-update-transient-drawing self :h (om-point-y size)))


(defmethod update-cursor ((self x-cursor-graduated-view) time &optional y1 y2)
  (unless (= (cursor-pos self) time)
    (setf (cursor-pos self) time))
  (om-update-transient-drawing self :x (time-to-pixel self (cursor-pos self))))

(defmethod update-view-from-ruler ((self x-ruler-view) (view x-cursor-graduated-view))
  ;(update-cursor-pos view)
  (update-cursor view (cursor-pos view))
  (call-next-method))

(defmethod time-to-pixel ((self x-cursor-graduated-view) time) 
  (x-to-pix self time))

(defmethod pixel-to-time ((self x-cursor-graduated-view) x) 
   (round (pix-to-x self x)))

(defmethod om-draw-contents :after ((self x-cursor-graduated-view))
  (when (play-obj? (get-obj-to-play (editor (om-view-window self))))
    (let ((i1 (time-to-pixel self (car (cursor-interval self))))
          (i2 (time-to-pixel self (cadr (cursor-interval self)))))
      (om-with-fg-color (om-make-color 0.8 0.7 0.7)
        (om-with-line '(3 3) 
          (om-with-line-size 1
            (om-draw-line i1 0 i1 (h self))
            (om-draw-line i2 0 i2 (h self)))))
      (om-draw-rect i1 0 (- i2 i1) (h self) :fill t :color (om-make-color-alpha (om-def-color :white) 0.2))
      )))

(defmethod om-view-click-handler ((self x-cursor-graduated-view) position)
  (let ((editor (editor (om-view-window self)))
        (bx (time-to-pixel self (car (cursor-interval self))))
        (ex (time-to-pixel self (cadr (cursor-interval self)))))          
    (cond ((om-point-in-line-p position (omp bx 0) (omp bx (h self)) 4)
           (change-interval-begin editor self position))
          ((om-point-in-line-p position (omp ex 0) (omp ex (h self)) 4)
           (change-interval-end editor self position))
          (t (start-interval-selection editor self position)))))

(defmethod om-view-doubleclick-handler ((self x-cursor-graduated-view) position)
  (let ((time (pixel-to-time self (om-point-x position))))
    (update-cursor self time)
    (editor-set-interval (editor (om-view-window self)) (list time time))
    (call-next-method)))

(defmethod om-view-mouse-motion-handler :around ((self x-cursor-graduated-view) position)
  (let ((bx (time-to-pixel self (car (cursor-interval self))))
        (ex (time-to-pixel self (cadr (cursor-interval self)))))
    (cond ((or (om-point-in-line-p position (omp bx 0) (omp bx (h self)) 4)
               (om-point-in-line-p position (omp ex 0) (omp ex (h self)) 4))
           (om-set-view-cursor self (om-get-cursor :h-size)))
          (t ;(om-set-view-cursor self nil)
             (call-next-method)))))

;;;=================================
;;; STANDARDIZED PLAY CONTROLS
;;;=================================

(defmethod make-play-button ((editor play-editor-mixin) &key size enable) 
  (setf (play-button editor)
        (om-make-graphic-object 'om-icon-button :size (or size (omp 16 16)) 
                                :icon 'icon-play-black :icon-pushed 'icon-play-green :icon-disabled 'icon-play-gray
                                :lock-push t :enabled enable
                                :action #'(lambda (b)
                                            (declare (ignore b))
                                            (editor-play editor)))))


(defmethod make-pause-button ((editor play-editor-mixin) &key size enable) 
  (setf (pause-button editor)
        (om-make-graphic-object 'om-icon-button :size (or size (omp 16 16)) 
                                :icon 'icon-pause-black :icon-pushed 'icon-pause-orange :icon-disabled 'icon-pause-gray
                                :lock-push t :enabled enable
                                :action #'(lambda (b)
                                            (declare (ignore b))
                                            (editor-pause editor)))))

(defmethod make-stop-button ((editor play-editor-mixin) &key size enable) 
  (setf (stop-button editor)
        (om-make-graphic-object 'om-icon-button :size (or size (omp 16 16)) 
                                :icon 'icon-stop-black :icon-pushed 'icon-stop-white :icon-disabled 'icon-stop-gray
                                :lock-push nil :enabled enable
                                :action #'(lambda (b)
                                            (declare (ignore b))
                                            (when (pause-button editor) (unselect (pause-button editor)))
                                            (when (play-button editor) (unselect (play-button editor)))
                                            (editor-stop editor)))))

(defmethod make-previous-button ((editor play-editor-mixin) &key size enable) 
  (setf (prev-button editor)
        (om-make-graphic-object 'om-icon-button :size (or size (omp 16 16)) 
                                :icon 'icon-previous-black :icon-pushed 'icon-previous-white :icon-disabled 'icon-previous-gray
                                :lock-push nil :enabled enable
                                :action #'(lambda (b)
                                            (declare (ignore b))
                                            (editor-previous-step editor)))))

(defmethod make-next-button ((editor play-editor-mixin) &key size enable) 
  (setf (next-button editor)
        (om-make-graphic-object 'om-icon-button :size (or size (omp 16 16)) 
                                :icon 'icon-next-black :icon-pushed 'icon-next-white :icon-disabled 'icon-next-gray
                                :lock-push nil :enabled enable
                                :action #'(lambda (b)
                                            (declare (ignore b))
                                            (editor-next-step editor)))))

(defmethod make-rec-button ((editor play-editor-mixin) &key size enable) 
  (setf (rec-button editor)
        (om-make-graphic-object 'om-icon-button :size (or size (omp 16 16)) 
                          :icon 'icon-record-black :icon-pushed 'icon-record-red :icon-disabled 'icon-record-gray
                          :lock-push t :enabled enable
                          :action #'(lambda (b)
                                      (declare (ignore b))
                                      (editor-record editor)))))


(defmethod make-repeat-button ((editor play-editor-mixin) &key size enable) 
  (setf (repeat-button editor)
        (om-make-graphic-object 'om-icon-button :size (or size (omp 16 16)) 
                          :icon 'icon-repeat-black :icon-pushed 'icon-repeat-white
                          :lock-push t :enabled enable
                          :action #'(lambda (b)
                                      (editor-repeat editor (pushed b))))))

(defmethod metronome-on ((self play-editor-mixin))
  (slot-value self 'metronome-on))

(defmethod (setf metronome-on) (t-or-nil (self play-editor-mixin))
  (setf (slot-value self 'metronome-on) t-or-nil)
  (when (metronome self)
    (if t-or-nil
        (if (eq (state (get-obj-to-play self)) :play)
            (player-play-object (player self) (metronome self) nil 
                                :interval (list (get-obj-time (get-obj-to-play self)) nil)))
      (player-stop-object (player self) (metronome self)))))

(defmethod (setf tempo) (new-tempo (self play-editor-mixin))
  (when (tempo-box self)
    (om-set-dialog-item-text (cadr (om-subviews (tempo-box self))) 
                             (format nil "~$" new-tempo))))

(defmethod time-signature ((self play-editor-mixin))
  (slot-value self 'time-signature))

(defmethod (setf time-signature) (new-signature (self play-editor-mixin))
  (setf (slot-value self 'time-signature) new-signature)
  (when (metronome self)
    (with-schedulable-object (metronome self)
                             (setf (time-signature (metronome self)) new-signature)))�)

(defmethod make-tempo-box ((editor play-editor-mixin) &key fg-color bg-color font)
  (declare (ignore bg-color font))
  (setf (tempo-box editor)
        (om-make-layout
         'om-row-layout 
         :delta 2
         :align :bottom
         :subviews (list
                    (om-make-di 'om-check-box :text "" :size (omp 15 16) :font (om-def-font :font1)
                                :checked-p (metronome-on editor)
                                :di-action #'(lambda (item)
                                               (setf (metronome-on editor) (om-checked-p item))))
                    (om-make-di 'om-simple-text 
                                :size (omp 50 16) 
                                :text "120.00"
                                :font (om-def-font :font2b) 
                                :fg-color (or fg-color (om-def-color :black)))
                    ;(om-make-graphic-object 'numbox 
                    ;                        :value 120
                    ;                        :bg-color (or bg-color (om-def-color :white))
                    ;                        :fg-color (or fg-color (om-def-color :black))
                    ;                        :size (om-make-point 23 16) 
                    ;                        :font (or font (om-def-font :font2b))
                    ;                        :min-val 20 :max-val 999
                    ;                        :change-fun #'(lambda (item)
                    ;                                       (setf (tempo editor) (+ (value item) (mod (tempo editor) 1)))))
                    ;(om-make-di 'om-simple-text 
                    ;            :size (omp 9 17) 
                    ;            :text " ."
                    ;            :font (om-def-font :font2b) 
                    ;            :fg-color (or fg-color (om-def-color :black)))
                    ;(om-make-graphic-object 'numbox 
                    ;                        :value 0
                    ;                        :bg-color (or bg-color (om-def-color :white))
                    ;                        :fg-color (or fg-color (om-def-color :black))
                    ;                        :border t
                    ;                        :size (om-make-point 20 16) 
                    ;                        :font (or font (om-def-font :font2b))
                    ;                        :min-val 0 :max-val 99
                    ;                        :change-fun #'(lambda (item)
                    ;                                       (setf (tempo editor) (+ (floor (tempo editor)) (/ (value item) 100.0)))))
                    ))))

(defmethod make-signature-box ((editor play-editor-mixin) &key fg-color bg-color font rulers)
  (setf (signature-box editor)
        (om-make-layout
         'om-row-layout 
         :delta 2
         :align :bottom
         :subviews (list
                    (om-make-di 'om-check-box :text "" :size (omp 15 16) :font (om-def-font :font1)
                                :checked-p nil
                                :di-action #'(lambda (item)
                                               (loop for ruler in rulers
                                                     do
                                                     (setf (signature-on ruler) (om-checked-p item)))))
                    (om-make-graphic-object 'numbox 
                                            :value 4
                                            :bg-color (or bg-color (om-def-color :white))
                                            :fg-color (or fg-color (om-def-color :black))
                                            :border t
                                            :size (om-make-point 17 16) 
                                            :font (or font (om-def-font :font2b))
                                            :min-val 1 :max-val 99
                                            :after-fun #'(lambda (item)
                                                           (setf (time-signature editor) (append (list (value item))
                                                                                                 (list (cadr (time-signature editor)))))))
                    (om-make-di 'om-simple-text :size (omp 9 17) :text "/"
                                :font (om-def-font :font1b) :fg-color (om-def-color :black))
                    (om-make-graphic-object 'numbox 
                                            :value 4
                                            :bg-color (or bg-color (om-def-color :white))
                                            :fg-color (or fg-color (om-def-color :black))
                                            :border t
                                            :size (om-make-point 20 16) 
                                            :font (or font (om-def-font :font2b))
                                            :min-val 0 :max-val 5
                                            :change-fun #'(lambda (item)
                                                            (set-value item (expt 2 (value item))))
                                            :after-fun #'(lambda (item)
                                                           (setf (time-signature editor) (append (list (car (time-signature editor)))
                                                                                                 (list (value item))))))))))


(defun time-display (time_ms &optional format)
  (multiple-value-bind (time_s ms)
      (floor (round time_ms) 1000)
    (multiple-value-bind (time_m s)
        (floor time_s 60)
      (multiple-value-bind (h m)
          (floor time_m 60)
        (list h m s ms)
        (if format 
            (format nil "~2,'0dh~2,'0dm~2,'0ds~3,'0d" h m s ms)
          (if (= h 0)
              (format nil "~2,'0d:~2,'0d:~3,'0d" m s ms)
            (format nil "~2,'0d:~2,'0d:~2,'0d:~3,'0d" h m s ms)))))))


; (om-make-font "Times" 13)
(defmethod make-time-monitor ((editor play-editor-mixin) &key time color font format) 
  (setf (time-monitor editor)
        (om-make-di 'om-multi-text :size (omp 100 17) :text (if time (time-display time format) "")
                    :font (or font (om-def-font :font2)) :fg-color (or color (om-def-color :black)))))
      

(defmethod set-time-display ((self play-editor-mixin) time)
  (when (time-monitor self) 
    (om-set-dialog-item-text (time-monitor self) (if time (time-display time) ""))))
   

(defmethod editor-key-action :around ((self play-editor-mixin) key) 
  (case key  
    (#\Space (editor-play/stop self) t)
    (#\p (editor-play/pause self) t)
    (#\s (editor-stop self) t)    
    (:om-key-esc 
     (if (equal '(0 0) (play-interval self))
         (call-next-method) ;; if the interval is already reset: check if there is another 'escape' to do
       (editor-reset-interval self))
     (editor-stop self) t)
    (otherwise (call-next-method))
    ))


(defmethod enable-play-controls ((self play-editor-mixin) t-or-nil)
  (mapc 
   #'(lambda (b) (when b (setf (enabled b) t-or-nil) (om-invalidate-view b)))
   (list (play-button self) (pause-button self) (stop-button self) (rec-button self) (repeat-button self) (prev-button self) (next-button self)))
  (when (time-monitor self) (set-time-display self (if t-or-nil 0 nil))))



;;;==========================
;;; A RULER WITH TIME GRADUATION + MOVING CURSOR
;;;==========================
(defclass time-ruler (x-ruler-view x-cursor-graduated-view)
  ((unit :accessor unit :initform :sec :initarg :unit)
   (bottom-p :accessor bottom-p :initform t :initarg :bottom-p) ;bottom-p indicates if the arrow need to be on the top or the bottom (default is on the top)
   (markers-p :accessor markers-p :initform t :initarg :markers-p) ;use or not markers
   (onset-p :accessor onset-p :initform t :initarg :onset-p) ;use or not onset for markers (maquette vs timeline)
   (snap-to-grid :accessor snap-to-grid :initform t :initarg :snap-to-grid)
   (selected-time-markers :accessor selected-time-markers :initform nil)) 
  (:default-initargs :vmin 0))

(defmethod start-cursor ((self time-ruler)) nil)


;;;;;;;;;;;;;;;;;
;;;;;DRAWING;;;;;
;;;;;;;;;;;;;;;;;

(defmethod unit-value-str ((self time-ruler) value &optional (unit-dur 0))
  (if (equal (unit self) :ms) (call-next-method)
    (if (> unit-dur 100) (format nil "~d" (round (/ value 1000.0)))
      (format nil 
              (cond ((= unit-dur 100) "~1$")
                    ((= unit-dur 10) "~2$")
                    ((= unit-dur 1) "~3$")
                    (t "~0$"))
              (/ value 1000.0)))))

(defmethod om-draw-contents ((self time-ruler))
  ;draw the markers
  (when (markers-p self)
    (loop for marker in (get-all-time-markers self)
          do
          (let ((pos (time-to-pixel self marker)))
            (om-with-fg-color (om-make-color 0.9 0.7 0 (if (find marker (selected-time-markers self)) 1 0.45))
              (om-draw-line pos 0 pos (h self))
              (if (bottom-p self)
                  (om-draw-polygon (list (omp (- pos 4) 0) 
                                         (omp (- pos 4) (- (h self) 5))
                                         (omp pos (h self))
                                         (omp (+ pos 4) (- (h self) 5))
                                         (omp (+ pos 4) 0) ) 
                                   :fill t)
                (om-draw-polygon (list (omp (- pos 4) (h self)) 
                                       (omp (- pos 4) 5)
                                       (omp pos  0)
                                       (omp (+ pos 4) 5)
                                       (omp (+ pos 4) (h self)))
                                 :fill t)
                )))))
  ;draw the play head
  ;(let ((pos (x-to-pix self (cursor-pos self))))
  ;  (om-with-fg-color (om-make-color 1 1 1 0.5)
  ;    (if (bottom-p self)
  ;        (om-draw-polygon (list (omp (- pos 5) (- (h self) 5))
  ;                               (omp (+ pos 5) (- (h self) 5))
  ;                               (omp pos (h self))) 
  ;                         :fill t)
  ;      (om-draw-polygon (list (omp (- pos 5)  5)
  ;                             (omp (+ pos 5) 5)
  ;;                             (omp pos  0)) 
  ;                       :fill t)))
  ;  (call-next-method))
  (call-next-method)
  )

(defmethod draw-grid-from-ruler ((self om-view) (ruler time-ruler))
  (when (markers-p ruler)
    (loop for marker in (get-all-time-markers ruler)
          do
          (let ((pos (time-to-pixel ruler marker)))
            (om-with-fg-color (om-make-color  0.9 0.7 0 (if (find marker (selected-time-markers ruler)) 1 0.45))
              (om-draw-line pos 0 pos (h self))))))
  (om-with-line '(2 2)
    (call-next-method)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SNAP TO GRID FUNCITONNALITIES;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod snap-time-to-grid  ((ruler time-ruler) time &optional (snap-delta nil))
  ;returns a time value corresponding to the given time aligned on the grid with a delta (in ms) treshold.
  ;default treshold is a tenth of the grid
  (let* ((unit-dur (get-units ruler))
         (delta (if snap-delta (min snap-delta (/ unit-dur 2)) (/ unit-dur 8)))
         (offset  (mod time unit-dur)))
    (if (> offset (- unit-dur delta))
        (- (+ time unit-dur) offset)
      (if (< offset delta)
          (- time offset)
        time))))


(defmethod snap-time-to-markers  ((ruler time-ruler) time &optional (snap-delta nil) (source-time nil))
  (let* ((unit-dur (get-units ruler))
         (delta  (if snap-delta (min snap-delta (/ unit-dur 2)) (/ unit-dur 8)))
         (markers (get-all-time-markers ruler))
         (pos nil)
         (pre-marker nil)
         (post-marker nil))
    (when source-time
      (let ((src-pos (position source-time markers)))
        (when src-pos
          (setf markers (remove-nth src-pos markers)))))
    (setf pos (or (position time markers  :test '<= ) (length markers)))
    (when (> pos 0)
      (setf pre-marker (nth (1- pos) markers)))
    (when (< pos (1- (length markers)))
      (setf post-marker (nth pos markers)))
    (if (and pre-marker (< (- time pre-marker) delta))
        pre-marker
      (if (and post-marker (< (- post-marker time) delta))
          post-marker
        time))))

(defmethod snap-time-to-grid-and-markers ((ruler time-ruler) time &optional (snap-delta nil) (source-time nil))
  (let* ((time-grid (snap-time-to-grid ruler time snap-delta))
         (time-marker (snap-time-to-markers ruler time snap-delta source-time))
         (d1 (if (equal time time-grid) most-positive-fixnum (abs (- time time-grid))))
         (d2 (if (equal time time-marker) most-positive-fixnum (abs (- time time-marker)))))
    (if (<= d2 d1) time-marker time-grid)))

;utilities to adapt dt for snap to grid functionnalities
(defmethod adapt-dt-for-grid ((ruler time-ruler) selected-point-time dt) 
  (let* ((newt (+ selected-point-time dt))
         (newt-grid (snap-time-to-grid ruler newt nil))
         (offset (- newt-grid newt)))
    (+ dt offset)))

(defmethod adapt-dt-for-markers ((ruler time-ruler) selected-point-time dt) 
  (let* ((newt (+ selected-point-time dt))
         (newt-grid (snap-time-to-markers ruler newt nil selected-point-time))
         (offset (- newt-grid newt)))
    (+ dt offset)))

(defmethod adapt-dt-for-grid-and-markers ((ruler time-ruler) selected-point-time dt &optional snap-delta) 
  (let* ((newt (+ selected-point-time dt))
         (newt-grid (snap-time-to-grid-and-markers ruler newt snap-delta selected-point-time))
         (offset (- newt-grid newt)))
    (+ dt offset)))


;;;;;;;;;;;;;;;;;;;;;;;
;TIME MARKERS API
;;;;;;;;;;;;;;;;;;;;;;;

;TO USE MARQUERS : 
;1) Have a child class of timed-objects and overload the get-time-markers method
;2) Have a child class of x-graduated view and overload the following methods
;    - get-timed-objects-for-graduated-view
;    - select-elements-at-time
;    - get-editor-for-graduated-view
;    - translate-editor-selection

;TIME MARKERS : method to redefine by subclasses
(defmethod get-timed-objects-for-graduated-view ((self x-graduated-view))
  "returns a list of timed-object to retrieve their markers"
  nil)

;TIME MARKERS method to redefine by subclasses
(defmethod select-elements-at-time ((self x-cursor-graduated-view) marker-time)
  "selects the elements with same time than the marker-time"
  nil)

;Enventually redefine this one
(defmethod clear-editor-selection ((self omeditor))
  (set-selection self nil))

;Enventually redefine this one
(defmethod get-editor-for-graduated-view ((self x-graduated-view))
  "returns the editor handling the graduated view/selection and translation for timed-objects"
  (editor self))

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;ACTIONS ands Utilities
;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod select-elements-from-marker ((self time-ruler) marker-time)
  (loop for ed in (get-related-views-editors self) do
        (clear-editor-selection ed))
  (loop for rv in (related-views self) do
        (select-elements-at-time rv marker-time)))

(defmethod get-onset ((self timed-object)) (onset self))
(defmethod get-onset ((self OMBox)) (get-box-onset self))

(defmethod get-all-time-markers ((self time-ruler))
  (sort (remove nil (flat (loop for view in (related-views self)
                                                   collect
                                                   (loop for timed-obj in (get-timed-objects-for-graduated-view view)
                                                         when timed-obj collect
                                                         (if (onset-p self)
                                                             (om+ (get-time-markers timed-obj) (get-onset timed-obj))
                                                           (get-time-markers timed-obj))
                                                         )))) '<))
  
(defmethod get-related-views-editors ((self time-ruler))
  (remove-duplicates (remove nil (loop for rv in (related-views self) collect (get-editor-for-graduated-view rv)))))

(defmethod find-marker-at-time ((self time-ruler) time)
  ;gets the first marker for each related views that is close of 5pix to the position of the mouse.
  (let ((delta-t (dpix-to-dx self 5)))
    (loop for marker-time in (get-all-time-markers self)
          when (and  (<= time  (+ delta-t marker-time))  (>= time (- marker-time delta-t)))  
          return marker-time
          )))

(defmethod translate-from-marker-action ((self time-ruler) marker position)
   (let* ((ref-time (pix-to-x self (om-point-x position)))
          (objs (remove nil (flat (loop for rv in (related-views self)
                                        collect
                                        (get-timed-objects-for-graduated-view rv)))))
          (obj-elem-list (loop for obj in objs collect
                               (list obj (get-elements-for-marker 
                                          obj  
                                          (if (onset-p self) (om- marker (get-onset obj)) marker))))))
     (om-init-temp-graphics-motion 
      self position nil 
      :min-move 4
      :motion #'(lambda (view pos)
                  (let* ((tmp_time (pixel-to-time view (om-point-x pos)))
                         (dt (round (- tmp_time ref-time)))
                         (new-dt (if (snap-to-grid self) (adapt-dt-for-grid-and-markers self marker dt) dt))) 
                    (when (not (zerop new-dt))
                      (loop for item in obj-elem-list do
                            (let ((obj (car item))
                                  (elem (cadr item)))
                              (translate-elements-from-time-marker obj elem new-dt)))
                      (loop for ed in (get-related-views-editors self)
                            do (update-to-editor ed self))
                      (setf (selected-time-markers self) 
                            (replace-in-list (selected-time-markers self) 
                                             (+ marker new-dt) 
                                             (position marker (selected-time-markers self))))
                      (setf marker (+ marker new-dt))
                      (setf ref-time (+ ref-time new-dt))
                      (mapcar 'om-invalidate-view (related-views self)) 
                      (om-invalidate-view self)))))))

;=========
;EVENTS
;=========

(defmethod om-view-click-handler ((self time-ruler) position)
  (if (markers-p self)
      (let* ((time (pix-to-x self (om-point-x position)))
             (marker (find-marker-at-time self time)))
        (if marker
            (progn
              (setf (selected-time-markers self) (list marker))
              (select-elements-from-marker self marker)
              (translate-from-marker-action self marker position))
          (call-next-method)))
    (call-next-method)))
  
(defmethod om-view-mouse-motion-handler ((self time-ruler) pos)
  (when (markers-p self)
    (if (find-marker-at-time self (pix-to-x self (om-point-x pos)))
        (om-set-view-cursor self nil)
      (om-set-view-cursor self (om-view-cursor self)))))

