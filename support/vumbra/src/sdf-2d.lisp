(in-package #:vumbra.sdf)

;;; Operations functions

(defun onion ((d :float)
              (r :float))
  (- (abs d) r))

(defun union ((d1 :float)
              (d2 :float))
  (min d1 d2))

(defun difference ((d1 :float)
                   (d2 :float))
  (max (- d1) d2))

(defun intersect ((d1 :float)
                  (d2 :float))
  (max d1 d2))

(defun union/smooth ((d1 :float)
                     (d2 :float)
                     (k :float))
  (let ((h (saturate (+ 0.5 (/ (* 0.5 (- d2 d1)) k)))))
    (- (mix d2 d1 h) (* k h (- 1 h)))))

(defun difference/smooth ((d1 :float)
                          (d2 :float)
                          (k :float))
  (let ((h (saturate (- 0.5 (/ (* 0.5 (+ d2 d1)) k)))))
    (+ (mix d2 (- d1) h) (* k h (- 1 h)))))

(defun intersect/smooth ((d1 :float)
                         (d2 :float)
                         (k :float))
  (let ((h (saturate (- 0.5 (/ (* 0.5 (- d2 d1)) k)))))
    (+ (mix d2 d1 h) (* k h (- 1 h)))))

(defun mask/fill ((dist :float))
  (saturate (- dist)))

(defun mask/inner-border ((dist :float)
                          (width :float))
  (- (saturate (+ dist width))
     (saturate dist)))

(defun mask/outer-border ((dist :float)
                          (width :float))
  (- (saturate dist)
     (saturate (- dist width))))

(defun shadow ((fn (function (:vec2) :float))
               (p :vec2)
               (pos :vec2)
               (radius :float))
  (let* ((dir (normalize (- pos p)))
         (dl (length (- p pos)))
         (lf (* radius dl))
         (dt 0.01))
    (dotimes (i 64)
      (let ((sd (funcall fn (+ p (* dir dt)))))
        (when (< sd (- radius))
          (return 0.0))
        (setf lf (min lf (/ sd dt)))
        (incf dt (max 1 (abs sd)))
        (when (> dt dl)
          (break))))
    (smoothstep 0 1 (saturate (/ (+ (* lf dl) radius) 2)))))

;;; 2D primitives

(defun dist/circle ((p :vec2)
                    (r :float))
  (- (length p) r))

(defun dist/box ((p :vec2)
                 (b :vec2))
  (let ((d (- (abs p) b)))
    (+ (length (max d 0))
       (min (max (.x d) (.y d)) 0))))

(defun dist/segment ((p :vec2)
                     (a :vec2)
                     (b :vec2))
  (let* ((pa (- p a))
         (ba (- b a))
         (h (saturate (/ (dot pa ba) (dot ba ba)))))
    (length (- pa (* ba h)))))

(defun dist/rhombus ((p :vec2)
                     (b :vec2))
  (flet ((ndot ((a :vec2)
                (b :vec2))
           (- (* (.x a) (.x b))
              (* (.y a) (.y b)))))
    (let* ((q (abs p))
           (h (clamp (/ (+ (* -2 (ndot q b)) (ndot b b)) (dot b b)) -1 1))
           (d (length (- q (* 0.5 b (vec2 (- 1 h) (1+ h)))))))
      (sign (- (+ (* (.x q) (.y b)) (* (.y q) (.x b)))
               (* (.x b) (.y b)))))))

(defun dist/triangle ((p :vec2)
                      (size :vec2))
  (let* ((p (vec2 (abs (.x p)) (.y p)))
         (a (- p (* size (saturate (/ (dot p size) (dot size size))))))
         (b (- p (* size (vec2 (saturate (/ (.x p) (.x size))) 1))))
         (k (sign (.y size)))
         (d (min (dot a a) (dot b b)))
         (s (max (* k (- (* (.x p) (.y size))
                         (* (.y p) (.x size))))
                 (* k (- (.y p) (.y size))))))
    (* (sqrt d) (sign s))))

(defun dist/pie ((p :vec2)
                 (angle :float))
  (let* ((angle (/ (radians angle) 2))
         (n (vec2 (cos angle) (sin angle))))
    (+ (* (.x (abs p)) (.x n))
       (* (.y p) (.y n)))))

(defun dist/semi-circle ((p :vec2)
                         (radius :float)
                         (angle :float)
                         (width :float))
  (let* ((width (/ width 2))
         (radius (- radius width)))
    (difference (dist/pie p angle)
                (- (abs (dist/circle p radius)) width))))

(defun dist/uneven-capsule ((p :vec2)
                            (r1 :float)
                            (r2 :float)
                            (h :float))
  (let* ((p (vec2 (abs (.x p)) (.y p)))
         (b (/ (- r1 r2) h))
         (a (sqrt (- 1 (* b b))))
         (k (dot p (vec2 (- b) a))))
    (cond
      ((minusp k)
       (- (length p) r1))
      ((> k (* a h))
       (- (length (- p (vec2 0 h))) r2))
      (t
       (- (dot p (vec2 a b)) r1)))))

(defun dist/pentagon ((p :vec2)
                      (r :float))
  (let ((k (vec3 0.809017 0.58778524 0.72654253))
        (p (vec2 (abs (.x p)) (.y p))))
    (decf p (* 2
               (min (dot (vec2 (- (.x k)) (.y k)) p) 0)
               (vec2 (- (.x k)) (.y k))))
    (decf p (* 2 (min (dot (.xy k) p) 0) (.xy k)))
    (decf p (vec2 (clamp (.x p) (* (- r) (.z k)) (* r (.z k))) r))
    (* (length p) (sign (.y p)))))

(defun dist/hexagon ((p :vec2)
                     (r :float))
  (let ((k (vec3 -0.8660254 0.5 0.57735026))
        (p (abs p)))
    (decf p (* 2 (min (dot (.xy k) p) 0) (.xy k)))
    (decf p (vec2 (clamp (.x p) (* (- (.z k)) r) (* (.z k) r)) r))
    (* (length p) (sign (.y p)))))

(defun dist/star5 ((p :vec2)
                   (r :float)
                   (rf :float))
  (let* ((k1 (vec2 0.809017 -0.58778524))
         (k2 (vec2 (- (.x k1)) (.y k1)))
         (p (vec2 (abs (.x p)) (.y p))))
    (decf p (* 2 (max (dot k1 p) 0) k1))
    (decf p (* 2 (max (dot k2 p) 0) k2))
    (decf (.y p) r)
    (let* ((p (vec2 (abs (.x p)) (.y p)))
           (ba (- (* rf (vec2 (- (.y k1)) (.x k1))) (vec2 0 1)))
           (h (clamp (/ (dot p ba) (dot ba ba)) 0 r)))
      (* (length (- p (* ba h)))
         (sign (- (* (.y p) (.x ba))
                  (* (.x p) (.y ba))))))))

(defun dist/star6 ((p :vec2)
                   (r :float))
  (let ((k (vec4 -0.5 0.8660254 0.57735026 1.7320508))
        (p (abs p)))
    (decf p (* 2 (min (dot (.xy k) p) 0) (.xy k)))
    (decf p (* 2 (min (dot (.yx k) p) 0) (.yx k)))
    (decf p (vec2 (clamp (.x p) (* r (.z k)) (* r (.w k))) r))
    (* (length p) (sign (.y p)))))

(defun dist/star ((p :vec2)
                  (r :float)
                  (n :int)
                  (m :float))
  (let* ((an (/ +pi+ n))
         (en (/ +pi+ m))
         (acs (vec2 (cos an) (sin an)))
         (ecs (vec2 (cos en) (sin en)))
         (bn (- (mod (atan (.x p) (.y p)) (* 2 an)) an))
         (p (* (length p) (vec2 (cos bn) (abs (sin bn))))))
    (decf p (* r acs))
    (incf p (* ecs (clamp (- (dot p ecs)) 0 (/ (* r (.y acs)) (.y ecs)))))
    (* (length p) (sign (.x p)))))

(defun dist/trapezoid ((p :vec2)
                       (r1 :float)
                       (r2 :float)
                       (he :float))
  (let* ((k1 (vec2 r2 he))
         (k2 (vec2 (- r2 r1) (* 2 he)))
         (p (vec2 (abs (.x p)) (.y p)))
         (ca (vec2 (- (.x p) (min (.x p) (if (minusp (.y p)) r1 r2)))
                   (- (abs (.y p)) he)))
         (cb (+ (-  p k1)
                (* k2 (saturate (/ (dot (- k1 p) k2) (dot k2 k2))))))
         (s (if (and (minusp (.x cb)) (minusp (.y ca))) -1 1)))
    (* s (sqrt (min (dot ca ca) (dot cb cb))))))

(defun dist/arc ((p :vec2)
                 (sca :vec2)
                 (scb :vec2)
                 (ra :float)
                 (rb :float))
  (let* ((p (* p (mat2 (.x sca) (.y sca) (- (.y sca)) (.x sca))))
         (p (vec2 (abs (.x p)) (.y p)))
         (k (if (> (* (.y scb) (.x p)) (* (.x scb) (.y p)))
                (dot (.xy p) scb)
                (length (.xy p)))))
    (- (sqrt (- (+ (dot p p) (* ra ra)) (* 2 ra k))) rb)))

(defun dist/vesica ((p :vec2)
                    (r :float)
                    (d :float))
  (let ((p (abs p))
        (b (sqrt (- (* r r) (* d d)))))
    (if (> (* (- (.y p) b) d)
           (* (.x p) b))
        (length (- p (vec2 0 b)))
        (- (length (- p (vec2 (- d) 0))) r))))

(defun dist/egg ((p :vec2)
                 (ra :float)
                 (rb :float))
  (let ((k (sqrt 3))
        (p (vec2 (abs (.x p)) (.y p)))
        (r (- ra rb)))
    (-
     (cond
       ((minusp (.y p))
        (- (length (vec2 (.x p) (.y p))) r))
       ((< (* k (+ (.x p) r)) (.y p))
        (length (vec2 (.x p) (- (.y p) (* k r)))))
       (t
        (- (length (vec2 (+ (.x p) r) (.y p))) (* 2 r))))
     rb)))

(defun dist/cross ((p :vec2)
                   (b :vec2)
                   (r :float))
  (let* ((p (abs p))
         (p (if (> (.y p) (.x p)) (.yx p) (.xy p)))
         (q (- p b))
         (k (max (.y q) (.x q)))
         (w (if (plusp k) q (- (vec2 (- (.y b) (.x p)) k)))))
    (+ (* (sign k) (length (max w 0))) r)))

(defun dist/rounded-x ((p :vec2)
                       (w :float)
                       (r :float))
  (let ((p (abs p)))
    (- (length (- p (* (min (+ (.x p) (.y p)) w) 0.5))) r)))

(defun dist/parabola ((pos :vec2)
                      (k :float))
  (let* ((pos (abs pos))
         (ik (/ k))
         (p (* ik (/ (- (.y pos) (* 0.5 ik)) 3)))
         (q (* 0.25 ik ik (.x pos)))
         (h (- (* q q) (* p p p)))
         (r (sqrt (abs h)))
         (x (if (plusp h)
                (- (pow (+ q r) (/ 3))
                   (* (pow (abs (- q r)) (/ 3)) (sign (- r q))))
                (* 2 (cos (/ (atan r q) 3)) (sqrt p)))))
    (* (length (- pos (vec2 x (* k x x))))
       (sign (- (.x pos) x)))))
