;;;=======================
;;; GUI / GRAPHIC API UTILS FOR OM
;;;=======================


(in-package :om)

;;;;======================================
;;;; Graphic components utilities 
;;;; muste be called on graphic objects only (window, view,dialog-item,...)
;;;;======================================
(defmethod x   ((self t)) (om-point-x (om-view-position self)))
(defmethod y   ((self t)) (om-point-y (om-view-position self)))
(defmethod w   ((self t)) (om-width self))
(defmethod h   ((self t)) (om-height self))
(defmethod x+w ((self t)) (+ (x self) (w self)))
(defmethod y+h ((self t)) (+ (y self) (h self)))

;;;===================
;;; POINTS/POSITIONS MANAGEMENT
;;;===================

(defmethod print-point (point)
  (if (om-point-p point)
      (let ((str (format nil "ompoint >>> x:~A y:~A" (om-point-x point) (om-point-y point))))
        (print str)
        point)
    (print point)))

(defun dot-prod-2D (p1 p2) (+ (* (om-point-x p1) (om-point-x p2)) (* (om-point-y p1) (om-point-y p2))))
(defun norm-2D (p)  (sqrt (dot-prod-2D p p))) 
(defun dist2D (p1 p2) (norm-2D (om-subtract-points p1 p2)))

(defun dist-to-line (pt lp1 lp2)
  (let  ((v (om-subtract-points lp2 lp1))
         (w (om-subtract-points pt lp1)))
    (let ((c1 (dot-prod-2D w v)))
      (if (<= c1 0 )
          (dist2D pt lp1)
        (let ((c2 (dot-prod-2D v v)))
          (if (<= c2 c1)
              (dist2D pt lp2)
            (let* ((b (/ c1 c2))
                   (pb  (om-add-points lp1 (om-make-point (round (* b (om-point-x v))) 
                                                          (round (* b (om-point-y v)))))))
              (dist2D pt pb))))))))


(defun om-point-in-line-p (pt lp1 lp2 delta)
  (<= (dist-to-line pt lp1 lp2) delta))



(defun om-point-in-rect-p (point rx ry rw rh)
  (let ((x1 (if (plusp rw) rx (+ rx rw)))
        (x2 (if (plusp rw) (+ rx rw) rx))
        (y1 (if (plusp rh) ry (+ ry rh)))
        (y2 (if (plusp rh) (+ ry rh) ry)))        
    (and (>= (om-point-x point) x1)
         (<= (om-point-x point) x2)
         (>= (om-point-y point) y1)
         (<= (om-point-y point) y2))))

(defun rect-intersection (r1x1 r1y1 r1x2 r1y2 r2x1 r2y1 r2x2 r2y2)
  (let ((r1x1 (min r1x1 r1x2))
        (r1x2 (max r1x1 r1x2))
        (r1y1 (min r1y1 r1y2))
        (r1y2 (max r1y1 r1y2))
        (r2x1 (min r2x1 r2x2))
        (r2x2 (max r2x1 r2x2))
        (r2y1 (min r2y1 r2y2))
        (r2y2 (max r2y1 r2y2)))
    (let ((tx (max r1x1 r2x1))
          (ty (max r1y1 r2y1))
          (t2x (min r1x2 r2x2))
          (t2y (min r1y2 r2y2)))
      (if (or (< t2x tx) (< t2y ty))
          NIL
	(list tx ty (- t2x tx) (- t2y ty))))))

;;;===================
;;; COLORS
;;;===================

(defconstant *golden_ratio_conjugate* 0.618033988749895)
 
(defun make-color (spec)
  (cond ((consp spec)
         (apply 'om-make-color spec))
        ((null spec)
         (om-random-color))
        ((symbolp spec)
         (om-def-color spec))
        (t (om-random-color))))

(defun om-make-color-255 (r g b)
  (om-make-color (/ r 255.0) (/ g 255.0) (/ b 255.0)))

(defun rgb2hsv (col)
  "convert RGB values into HSV values (list in float format (0.0 to 1.0))"
  (let* (
         ;be sure we have a correct range for input
         (r (min (nth 0 col) 1.0))
         (r (max r 0.0))
         (g (min (nth 1 col) 1.0))
         (g (max g 0.0))
         (b (min (nth 2 col) 1.0))
         (b (max b 0.0))
         (min_rgb (min r g b))
         (max_rgb (max r g b))
         )
    (if (= min_rgb max_rgb)
        (list 0.0 0.0 min_rgb)
      (progn
        (let* (
               (tmp_d (if (= r min_rgb) (- g b) ( if (= b min_rgb) (- r g) (- b r))))
               (tmp_h (if (= r min_rgb) 3 (if (= b min_rgb) 1 5)))
               (h (/ (* 60 (- tmp_h (/ tmp_d (- max_rgb min_rgb)))) 360))
               (v max_rgb)
               (s (/ (- max_rgb min_rgb) max_rgb)))
          (list h s v))))))

(defun hsv2rgb (col)
  "convert HSV values into RGB values (list in float format (0.0 to 1.0))"
  (let* (
         (h (min 1.0 (nth 0 col)))
         (s (min 1.0 (nth 1 col)))
         (v (min 1.0 (nth 2 col)))
         (i (floor (* h 6)))
         (f (- (* h 6) i))
         (p (* v (- 1 s)))
         (q (* v (- 1 (* f s))))
         (tt (* v (- 1 (* (- 1 f) s)))))
    (case (mod i 6) 
      (0 (list v tt p))
      (1 (list q v p))
      (2 (list p v tt))
      (3 (list p q v))
      (4 (list tt p v))
      (5 (list v p q)))))

(defmethod om-make-color-hsv (h s v &optional (alpha 1.0))
  "create a omcolor with h s v float input"
  (let*((rgb (hsv2rgb (list h s v)))
        (r (nth 0 rgb))
        (g (nth 1 rgb))
        (b (nth 2 rgb)))
  (om-make-color r g b alpha)))

(defun om-interpole-colors (begin end steps)
  (if (< steps 2)
    (list begin end)
  (let* ((difR (/ (- (om-color-r end) (om-color-r begin)) steps))
         (difG (/ (- (om-color-g end) (om-color-g begin)) steps))
         (difB (/ (- (om-color-b end) (om-color-b begin)) steps)))
    (loop for i from 0 to (- steps 1)
          collect (om-make-color
                   (float (+ (* i difR) (om-color-r begin)))
                   (float (+ (* i difG) (om-color-g begin)))
                   (float (+ (* i difB) (om-color-b begin))))))))

(defun om-random-color (&optional (alpha 1.0))
  (om-make-color (om-random 0.0 1.0) (om-random 0.0 1.0) (om-random 0.0 1.0) alpha))

(defmethod om-random-color-hsv (s v &optional (alpha 1.0))
  (om-make-color-hsv (om-random 0.0 1.0) s v alpha))

(defmethod om-create-palette-from-color (col size)
  "Creates a palette of colors spaced with golden ratio for readability. It use a first color as source and and number of colors to generate"
  (let* ((r (om-color-r col))
         (g (om-color-g col))
         (b (om-color-b col))
         (hsv (rgb2hsv (list r g b))))
    (loop for i from 0 to (1- size)
          collect
          (om-make-color-hsv (mod (+ (nth 0 hsv) (* i *golden_ratio_conjugate* )) 1.0) (nth 1 hsv) (nth 2 hsv))
          )))

(defmethod find-next-color-in-golden-palette (col)
  "compute the next color spaced by the golden ratio from the previous one in hue"
  (let* ((r (om-color-r col))
         (g (om-color-g col))
         (b (om-color-b col))
         (hsv (rgb2hsv (list r g b))))
    (om-make-color-hsv (mod (+ (nth 0 hsv) *golden_ratio_conjugate*) 1.0) (nth 1 hsv) (nth 2 hsv))))




(defun om-get-dark-offset-color (col factor)
  (let ((r (max 0.0 (- (om-color-r col) factor)))
        (g (max 0.0 (- (om-color-g col) factor)))
        (b (max 0.0 (- (om-color-b col) factor))))
    (om-make-color r g b)))

(defun om-get-light-offset-color (col factor)
  (let ((r (min 1.0 (+ (om-color-r col) factor)))
        (g (min 1.0 (+ (om-color-g col) factor)))
        (b (min 1.0 (+ (om-color-b col) factor))))
    (om-make-color r g b)))

(defun om-get-saturated-color (col)
  (let* ((r (om-color-r col))
         (g (om-color-g col))
         (b (om-color-b col))
         (hsv (rgb2hsv (list r g b))))
    (om-make-color-hsv (nth 0 hsv) 1.0 1.0)))


(defun om-get-darker-color (col factor)
  (let* ((r (om-color-r col))
        (g (om-color-g col))
        (b (om-color-b col))
        (hsv (rgb2hsv (list r g b)))
        (new_v (max 0.0 (- (nth 2 hsv) factor))))
     (om-make-color-hsv (nth 0 hsv) (nth 1 hsv) new_v)))

(defun om-get-lighter-color (col factor)
  (let* ((r (om-color-r col))
        (g (om-color-g col))
        (b (om-color-b col))
        (hsv (rgb2hsv (list r g b)))
        (new_v (min 1.0 (+ (nth 2 hsv) factor))))
    (om-make-color-hsv (nth 0 hsv) (nth 1 hsv) new_v)))


;;;===================
;;; OM cursors 
;;;===================

(defvar *om-contex-cursor* nil)
(defvar *om-loupe-cursor* nil)
(defvar *om-point-cursor* nil)
(defvar *om-pen-cursor* nil)


(defun init-curs ()
  
  (om-set-cursor-location (om-relative-path '("resources" "curs") nil :om))
  
  (oa::om-init-cursors)
  
  (om-add-cursor :context-menu "contex-cursor")
  (om-add-cursor :add "+-cursor")
  (om-add-cursor :loupe "loupe-cursor" (om-make-point 6 6))
  (om-add-cursor :pen "pen-cursor" (om-make-point 2 10))
  (om-add-cursor :point "point-cursor" (om-make-point 4 4))
  )

(om-add-init-fun 'init-curs)


;;;============================================
;;; TEMP-GRAPHICS
;;;============================================

(defclass selection-rectangle (om-item-view) ())

;;; selection rectangle can have negative sizes
(defmethod om-draw-contents ((self selection-rectangle))
  (let ((x (if (plusp (w self)) 0 -2))
        (y (if (plusp (h self)) 0 -2))
        (w (- (w self) (if (plusp (w self)) 1 -4)))
        (h (- (h self) (if (plusp (h self)) 1 -4))))
    (om-draw-rect x y w h :line 1 :color (om-def-color :selection-a) :fill t)
    (om-draw-rect x y w h :line 1 :color (om-def-color :selection-inv) :angles :round)
    ))

(defmethod oa::default-motion-action ((self selection-rectangle) position)
  (om-set-view-size self (om-subtract-points position (oa::init-pos oa::*global-motion-handler*))))

(defclass drag-line (om-item-view) ())

;;; selection rectangle can have negative sizes
(defmethod om-draw-contents ((self drag-line))
  (let ((x (if (plusp (w self)) 0 -2))
        (y (if (plusp (h self)) 0 -2))
        (w (- (w self) (if (plusp (w self)) 1 -4)))
        (h (- (h self) (if (plusp (h self)) 1 -4))))
    (om-with-fg-color (om-def-color :gray)
      (om-with-line-size 2 (om-draw-line x y w h))
      )
    ))



;;;================================================
;;; SPLINE CURVES
;;;================================================

;;; SPLINE CURVES - JB
;;; algo adapted from P. Bourke
;;; http://astronomy.swin.edu.au/~pbourke/curves/spline/
(defun spline (points degree resolution)
  (let* ((N (- (length points) 1))
         (knots (SplineKnots N degree)))
    (SplineCurve2D points N knots degree resolution)))

;; This returns the point "output" on the spline curve.
;; The parameter "v" indicates the position, it ranges from 0 to n-t+2
;; u = int*, n = int, tt = int, v = double, control = XYZ*, output = XYZ*   
(defun SplinePoint (u n tt v control)
  (let ((b 0)
        (outp (list 0 0 0)))
    (loop for k = 0 then (+ k 1)
          while (<= k n) do 
          (setf b (SplineBlend k tt u v))
          (setf (nth 0 outp) (+ (nth 0 outp) (* (nth 0 (nth k control)) b)))
          (setf (nth 1 outp) (+ (nth 1 outp) (* (nth 1 (nth k control)) b)))
          (setf (nth 2 outp) (+ (nth 2 outp) (* (nth 2 (nth k control)) b)))
          )
    outp))

(defun SplinePoint2D (u n tt v control)
  (let ((b 0)
        (outp (list 0 0)))
    (loop for k = 0 then (+ k 1)
          while (<= k n) do 
          (setf b (SplineBlend k tt u v))
          (setf (nth 0 outp) (+ (nth 0 outp) (* (nth 0 (nth k control)) b)))
          (setf (nth 1 outp) (+ (nth 1 outp) (* (nth 1 (nth k control)) b)))
          )
    outp))

;; Calculate the blending value, this is done recursively.
;; If the numerator and denominator are 0 the expression is 0.
;; If the deonimator is 0 the expression is 0
;; k = int, tt = int, u = int*, v = double
(defun SplineBlend (k tt u v)
  (let ((value 0))
    (setf value
          (if (= tt 1)
            (if (and (<= (nth k u) v) (< v (nth (+ k 1) u)))
              1 0)
          
            (if (and (= (nth (+ k tt -1) u) (nth k u)) (= (nth (+ k tt) u) (nth (+ k 1) u)))
              0 
              (if (= (nth (+ k tt -1) u) (nth k u))
                (* (/ (- (nth (+ tt k) u) v) (- (nth (+ tt k) u) (nth (+ k 1) u))) (SplineBlend (+ k 1) (- tt 1) u v))
                (if (= (nth (+ tt k) u) (nth (+ k 1) u))
                  (* (/ (- v (nth k u)) (- (nth (+ k tt -1) u) (nth k u))) (SplineBlend k (- tt 1) u v))
                  (+ (* (/ (- v (nth k u)) (- (nth (+ tt k -1) u) (nth k u))) (SplineBlend k (- tt 1) u v))  
                     (* (/ (- (nth (+ k tt) u) v) (- (nth (+ k tt) u) (nth (+ k 1) u)))  (SplineBlend (+ k 1) (- tt 1) u v)))
                  )))))
    value))


;; The positions of the subintervals of v and breakpoints, the position
;; on the curve are called knots. Breakpoints can be uniformly defined
;; by setting u[j] = j, a more useful series of breakpoints are defined
;; by the function below. This set of breakpoints localises changes to
;; the vicinity of the control point being modified.
;; u = int*, n = int, tt = int
(defun SplineKnots (n tt)
  (let ((u (make-sequence 'list (+ n tt 1)))) 
    (loop for j = 0 then (+ j 1)
          while (<= j (+ n tt)) do
          (if (< j tt)
            (setf (nth j u) 0)
            (if (<= j n)
           (setf (nth j u) (+ j (- tt) 1))
           (if (> j n)
             (setf (nth j u) (+ n (- tt) 2)))))
          )
    u))	



;; Create all the points along a spline curve
;; Control points "inp", "n" of them.
;; Knots "knots", degree "t".
;; Ouput curve "outp", "res" of them.
;; inp = XYZ*, n = int, knots = int*, tt = int, outp = XYZ*, res = int
(defun SplineCurve (inp n knots tt res)
  (let ((outp (make-sequence 'list res))
        (interval 0)
        (increment (/ (+ n (- tt) 2) (float (- res 1)))))
    (loop for i = 0 then (+ i 1)
          while (< i (- res 1)) do
          (setf (nth i outp) (SplinePoint knots n tt interval inp))
          (incf interval increment))
    (setf (nth (- res 1) outp) (nth n inp))
    outp))

(defun SplineCurve2D (inp n knots tt res)
  (let ((outp (make-sequence 'list res))
        (interval 0)
        (increment (/ (+ n (- tt) 2) (float (- res 1)))))
    (loop for i = 0 then (+ i 1)
          while (< i (- res 1)) do
          (setf (nth i outp) (SplinePoint2D knots n tt interval inp))
          (incf interval increment))
    (setf (nth (- res 1) outp) (nth n inp))
    outp))


;; Example of how to call the spline functions
;;Basically one needs to create the control points, then compute
;; the knot positions, then calculate points along the curve.

;define N 3
;XYZ inp[N+1] = {0.0,0.0,0.0,   1.0,0.0,3.0,   2.0,0.0,1.0,   4.0,0.0,4.0};
;define T 3
;int knots[N+T+1];
;define RESOLUTION 200
;XYZ outp[RESOLUTION];
