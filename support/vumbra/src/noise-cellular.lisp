(in-package #:vumbra.noise)

;;;; Cellular noise
;;;; Brian Sharpe https://github.com/BrianSharpe/GPU-Noise-Lib

(defun cellular-weight-samples ((samples :vec4))
  (let ((samples (1- (* samples 2))))
    (- (* samples samples samples) (sign samples))))

;;; 2D Cellular noise

(defun cellular ((point :vec2)
                 (hash-fn (function (:vec2) (:vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (jitter-window 0.25)
           (hash-x hash-y (funcall hash-fn cell))
           (grad-x (+ (* (cellular-weight-samples hash-x) jitter-window)
                      (vec4 0 1 0 1)))
           (grad-y (+ (* (cellular-weight-samples hash-y) jitter-window)
                      (vec4 0 0 1 1)))
           (dx (- (.x vec) grad-x))
           (dy (- (.y vec) grad-y))
           (d (+ (* dx dx) (* dy dy)))
           (d (vec4 (min (.xy d) (.zw d)) (.zw d))))
    (* (min (.x d) (.y d)) (/ 1.125))))

(defun cellular ((point :vec2))
  (cellular point (lambda ((x :vec2)) (hash:fast32/2-per-corner x))))

;;; 2D Cellular noise with derivatives

(defun cellular/derivs ((point :vec2)
                        (hash-fn (function (:vec2) (:vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (jitter-window 0.25)
           (hash-x hash-y (funcall hash-fn cell))
           (grad-x (+ (* (cellular-weight-samples hash-x) jitter-window)
                      (vec4 0 1 0 1)))
           (grad-y (+ (* (cellular-weight-samples hash-y) jitter-window)
                      (vec4 0 0 1 1)))
           (dx (- (.x vec) grad-x))
           (dy (- (.y vec) grad-y))
           (d (+ (* dx dx) (* dy dy)))
           (t1 (if (< (.x d) (.y d))
                   (vec3 (.x d) (.x dx) (.x dy))
                   (vec3 (.y d) (.y dx) (.y dy))))
           (t2 (if (< (.z d) (.w d))
                   (vec3 (.z d) (.z dx) (.z dy))
                   (vec3 (.w d) (.w dx) (.w dy)))))
    (* (if (< (.x t1) (.x t2)) t1 t2)
       (vec3 1 2 2)
       (/ 1.125))))

(defun cellular/derivs ((point :vec2))
  (cellular/derivs point
                   (lambda ((x :vec2))
                     (hash:fast32/2-per-corner x))))

;;; 2D Cellular noise (fast version)

(defun cellular-fast ((point :vec2)
                      (hash-fn (function (:vec2) (:vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (jitter-window (vec3 0.4 -0.4 0.6))
           (hash-x hash-y (funcall hash-fn cell))
           (grad-x (+ (* hash-x (.x jitter-window) 2) (.yzyz jitter-window)))
           (grad-y (+ (* hash-y (.x jitter-window) 2) (.yyzz jitter-window)))
           (dx (- (.x vec) grad-x))
           (dy (- (.y vec) grad-y))
           (d (+ (* dx dx) (* dy dy)))
           (d (vec4 (min (.xy d) (.zw d)) (.zw d))))
    (* (min (.x d) (.y d)) (/ 1.125))))

(defun cellular-fast ((point :vec2))
  (cellular-fast point
                 (lambda ((x :vec2))
                   (hash:fast32/2-per-corner x))))

;;; 3D Cellular noise

(defun cellular ((point :vec3)
                 (hash-fn
                  (function (:vec3)
                   (:vec4 :vec4 :vec4 :vec4 :vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (jitter-window (/ 6.0))
           (hash-x0 hash-y0 hash-z0 hash-x1 hash-y1 hash-z1
                    (funcall hash-fn cell))
           (hash-x0 (+ (* (cellular-weight-samples hash-x0) jitter-window)
                       (vec4 0 1 0 1)))
           (hash-y0 (+ (* (cellular-weight-samples hash-y0) jitter-window)
                       (vec4 0 0 1 1)))
           (hash-z0 (* (cellular-weight-samples hash-z0) jitter-window))
           (hash-x1 (+ (* (cellular-weight-samples hash-x1) jitter-window)
                       (vec4 0 1 0 1)))
           (hash-y1 (+ (* (cellular-weight-samples hash-y1) jitter-window)
                       (vec4 0 0 1 1)))
           (hash-z1 (+ (* (cellular-weight-samples hash-z1) jitter-window) 1))
           (dx1 (- (.x vec) hash-x0))
           (dy1 (- (.y vec) hash-y0))
           (dz1 (- (.z vec) hash-z0))
           (dx2 (- (.x vec) hash-x1))
           (dy2 (- (.y vec) hash-y1))
           (dz2 (- (.z vec) hash-z1))
           (d2 (+ (* dx2 dx2) (* dy2 dy2) (* dz2 dz2)))
           (d1 (min (+ (* dx1 dx1) (* dy1 dy1) (* dz1 dz1)) d2))
           (d1 (min (.xy d1) (.wz d1))))
    (* (min (.x d1) (.y d1)) 0.75)))

(defun cellular ((point :vec3))
  (cellular point (lambda ((x :vec3)) (hash:fast32/3-per-corner x))))

;;; 3D Cellular noise with derivatives

(defun cellular/derivs ((point :vec3)
                        (hash-fn
                         (function
                          (:vec3)
                          (:vec4 :vec4 :vec4 :vec4 :vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (jitter-window 0.16666667)
           (hash-x0 hash-y0 hash-z0 hash-x1 hash-y1 hash-z1
                    (funcall hash-fn cell))
           (hash-x0 (+ (* (cellular-weight-samples hash-x0) jitter-window)
                       (vec4 0 1 0 1)))
           (hash-y0 (+ (* (cellular-weight-samples hash-y0) jitter-window)
                       (vec4 0 0 1 1)))
           (hash-z0 (+ (* (cellular-weight-samples hash-z0) jitter-window)
                       (vec4 0)))
           (hash-x1 (+ (* (cellular-weight-samples hash-x1) jitter-window)
                       (vec4 0 1 0 1)))
           (hash-y1 (+ (* (cellular-weight-samples hash-y1) jitter-window)
                       (vec4 0 0 1 1)))
           (hash-z1 (+ (* (cellular-weight-samples hash-z1) jitter-window)
                       (vec4 1)))
           (dx1 (- (.x vec) hash-x0))
           (dy1 (- (.y vec) hash-y0))
           (dz1 (- (.z vec) hash-z0))
           (dx2 (- (.x vec) hash-x1))
           (dy2 (- (.y vec) hash-y1))
           (dz2 (- (.z vec) hash-z1))
           (d1 (+ (* dx1 dx1) (* dy1 dy1) (* dz1 dz1)))
           (d2 (+ (* dx2 dx2) (* dy2 dy2) (* dz2 dz2)))
           (r1 (if (< (.x d1) (.y d1))
                   (vec4 (.x d1) (.x dx1) (.x dy1) (.x dz1))
                   (vec4 (.y d1) (.y dx1) (.y dy1) (.y dz1))))
           (r2 (if (< (.z d1) (.w d1))
                   (vec4 (.z d1) (.z dx1) (.z dy1) (.z dz1))
                   (vec4 (.w d1) (.w dx1) (.w dy1) (.w dz1))))
           (r3 (if (< (.x d2) (.y d2))
                   (vec4 (.x d2) (.x dx2) (.x dy2) (.x dz2))
                   (vec4 (.y d2) (.y dx2) (.y dy2) (.y dz2))))
           (r4 (if (< (.z d2) (.w d2))
                   (vec4 (.z d2) (.z dx2) (.z dy2) (.z dz2))
                   (vec4 (.w d2) (.w dx2) (.w dy2) (.w dz2))))
           (t1 (if (< (.x r1) (.x r2)) r1 r2))
           (t2 (if (< (.x r3) (.x r4)) r3 r4)))
    (* (if (< (.x t1) (.x t2)) t1 t2)
       (vec4 1 2 2 2)
       0.75)))

(defun cellular/derivs ((point :vec3))
  (cellular/derivs point
                   (lambda ((x :vec3))
                     (hash:fast32/3-per-corner x))))

;;; 3D Cellular noise (fast version)

(defun cellular-fast ((point :vec3)
                      (hash-fn
                       (function
                        (:vec3)
                        (:vec4 :vec4 :vec4 :vec4 :vec4 :vec4))))
  (mvlet* ((cell (floor point))
           (vec (- point cell))
           (jitter-window (vec3 0.4 -0.4 0.6))
           (hash-x0 hash-y0 hash-z0 hash-x1 hash-y1 hash-z1
                    (funcall hash-fn cell))
           (hash-x0 (+ (* hash-x0 (.x jitter-window) 2) (.yzyz jitter-window)))
           (hash-y0 (+ (* hash-y0 (.x jitter-window) 2) (.yyzz jitter-window)))
           (hash-z0 (+ (* hash-z0 (.x jitter-window) 2) (.y jitter-window)))
           (hash-x1 (+ (* hash-x1 (.x jitter-window) 2) (.yzyz jitter-window)))
           (hash-y1 (+ (* hash-y1 (.x jitter-window) 2) (.yyzz jitter-window)))
           (hash-z1 (+ (* hash-z1 (.x jitter-window) 2) (.z jitter-window)))
           (dx1 (- (.x vec) hash-x0))
           (dy1 (- (.y vec) hash-y0))
           (dz1 (- (.z vec) hash-z0))
           (dx2 (- (.x vec) hash-x1))
           (dy2 (- (.y vec) hash-y1))
           (dz2 (- (.z vec) hash-z1))
           (d2 (+ (* dx2 dx2) (* dy2 dy2) (* dz2 dz2)))
           (d1 (min (+ (* dx1 dx1) (* dy1 dy1) (* dz1 dz1)) d2))
           (d1 (min (.xy d1) (.wz d1)) ))
    (* (min (.x d1) (.y d1)) (/ 9 12.0))))

(defun cellular-fast ((point :vec3))
  (cellular-fast point
                 (lambda ((x :vec3))
                   (hash:fast32/3-per-corner x))))
