(in-package #:virality.examples.shaders)

;;; Art 1
;;; WIP: A Truchet effect across a quad grid.
;;; TODO: This needs fixing to make the mask UV seamlessly tile.

(define-function art1/hash ((p :vec2))
  (let* ((p (fract (* p (vec2 385.18692 958.5519))))
         (p (+ p (dot p (+ p 42.4112)))))
    (fract (* (.x p) (.y p)))))

(define-function art1/frag (&uniform
                            (res :vec2)
                            (time :float))
  (let* ((scale 4)
         (uv (* (/ (- (.xy gl-frag-coord) (* res 0.5)) (.y res)) scale))
         (cell-id (floor uv))
         (checker (1- (* (mod (+ (.x cell-id) (.y cell-id)) 2) 2)))
         (hash (art1/hash cell-id))
         (grid-uv (- (fract (if (< hash 0.5) (* uv (vec2 -1 1)) uv)) 0.5))
         (circle-uv (- grid-uv
                       (* (sign (+ (.x grid-uv) (.y grid-uv) 1e-7)) 0.5)))
         (dist (length circle-uv))
         (width 0.2)
         (angle (atan (.x circle-uv) (.y circle-uv)))
         (mask (smoothstep 0.01 -0.01 (- (abs (- dist 0.5)) width)))
         (mask-uv (vec2 (fract (/ angle +half-pi+))
                        (* (abs (- (/ (- dist (- 0.5 width)) (* width 2))
                                   0.5))
                           2)))
         (noise (vec3 (+ (* 0.4 (shd/noise:perlin (* 2 mask-uv)))
                         (* 0.3 (shd/noise:perlin-surflet (* 16 mask-uv))))))
         (noise (* noise (vec3 0.6 0.9 0.7) (+ 0.5 (* 0.5 (vec3 uv 1))))))
    (vec4 (* noise mask) 1)))

(define-shader art1 ()
  (:vertex (shd/tex:unlit/vert-nil mesh-attrs))
  (:fragment (art1/frag)))

;;; Art 2
;;; Trippy effect that navigates erratically around the inside of a surreal
;;; toroidal disco-like world.

(define-function art2/check-ray ((distance :float))
  (< distance 1e-3))

(define-function art2/frag (&uniform
                            (res :vec2)
                            (time :float))
  (let* ((rtime (* time 0.5))
         (uv (* (/ (- (.xy gl-frag-coord) (* res 0.5)) (.y res))
                (mat2 (cos rtime) (- (sin rtime)) (sin rtime) (cos rtime))))
         (ray-origin (vec3 0 0 -1))
         (look-at (mix (vec3 0) (vec3 -1 0 -1) (sin (+ (* time 0.5) 0.5))))
         (zoom (mix 0.2 0.7 (+ (* (sin time) 0.5) 0.5)))
         (forward (normalize (- look-at ray-origin)))
         (right (normalize (cross (vec3 0 1 0) forward)))
         (up (cross forward right))
         (center (+ ray-origin (* forward zoom)))
         (intersection (+ (* (.x uv) right)
                          (* (.y uv) up)
                          center))
         (ray-direction (normalize (- intersection ray-origin)))
         (distance-surface 0.0)
         (distance-origin 0.0)
         (point (vec3 0))
         (radius (mix 0.3 0.8 (+ 0.5 (* 0.5 (sin (* time 0.4)))))))

    (dotimes (i 1000)
      (setf point (+ (* ray-direction distance-origin)
                     ray-origin)
            distance-surface (- (- (length (vec2 (1- (length (.xz point)))
                                                 (.y point)))
                                   radius)))
      (when (art2/check-ray distance-surface)
        (break))
      (incf distance-origin distance-surface))

    (let ((color (vec3 0)))
      (when (art2/check-ray distance-surface)
        (let* ((x (+ (atan (.x point) (- (.z point))) (* time 0.4)))
               (y (atan (1- (length (.xz point))) (.y point)))
               (ripples (+ (* (sin (* (+ (* y 60) (- (* x 20))) 3)) 0.5) 0.5))
               (waves (sin (+ (* x 2) (+ (- (* y 6)) (* time 5)))))
               (bands (sin (+ (* x 30) (* y 10))))
               (b1 (smoothstep -0.2 0.2 bands))
               (b2 (smoothstep -0.2 0.2 (- bands 0.5)))
               (noise (vec3 (+ (* 0.4 (shd/noise:perlin (* (vec2 x y) 10)))
                               (* 0.7 (shd/noise:cellular (* (vec2 x y) 50)))
                               (* 0.3 (shd/noise:perlin-surflet
                                       (* (vec2 x y) 200))))))
               (noise (shd/color:color-filter noise
                                              (vec3 (sin x) (sin y) 0.5)
                                              1))
               (blend (+ (max (* b1 (- 1 b2)) (* ripples b2 waves))
                         (* waves 0.5 b2)))
               (blend (mix blend
                           (- 1 blend)
                           (smoothstep -0.3 0.3 (sin (+ (* x 2) time))))))
          (setf color (mix (vec3 blend) noise 0.5))))
      (vec4 color 1))))

(define-shader art2 ()
  (:vertex (shd/tex:unlit/vert-nil mesh-attrs))
  (:fragment (art2/frag)))

;;; Art 3
;;; A variation of Art 2 modified by Peter Keller
;;; Adds some distortion to the torus radius to give it more of an organic look,
;;; and other tweaks.

(define-function art3/frag (&uniform
                            (res :vec2)
                            (time :float))
  (let* ((rtime (* time 0.10))
         (uv (* (/ (- (.xy gl-frag-coord) (* res 0.5)) (.y res))
                (mat2 (cos rtime) (- (sin rtime)) (sin rtime) (cos rtime))))
         (ray-origin (vec3 0 0 -1))
         (look-at (mix (vec3 0) (vec3 -1 0 -1) (sin (+ (* time 0.05) 0.05))))
         (zoom (mix 0.2 0.3 (+ (* (sin (* time .25)) 0.5) 0.5)))
         (forward (normalize (- look-at ray-origin)))
         (right (normalize (cross (vec3 0 1 0) forward)))
         (up (cross forward right))
         (center (+ ray-origin (* forward zoom)))
         (intersection (+ (* (.x uv) right)
                          (* (.y uv) up)
                          center))
         (ray-direction (normalize (- intersection ray-origin)))
         (distance-surface 0.0)
         (distance-origin 0.0)
         (point (vec3 0))
         (p (* .4 (shd/noise:perlin (* uv 4))))
         (radius (mix 0.6 0.9 (* (sin (* p 4))
                                 (cos (* p 2))))))

    (dotimes (i 1000)
      (setf point (+ (* ray-direction distance-origin)
                     ray-origin)
            distance-surface (- (- (length (vec2 (1- (length (.xz point)))
                                                 (.y point)))
                                   radius)))
      (when (art2/check-ray distance-surface)
        (break))
      (incf distance-origin distance-surface))

    (let ((color (vec3 0)))
      (when (art2/check-ray distance-surface)
        (let* ((x (+ (atan (.x point) (- (.z point))) (* time 0.4)))
               (y (atan (1- (length (.xz point))) (.y point)))
               (ripples (+ (* (sin (* (+ (* y 60) (- (* x 20))) 3)) 0.5) 0.5))
               (waves (sin (+ (* x 2) (+ (- (* y 6)) (* time 5)))))
               (bands (sin (+ (* x 30) (* y 50))))
               (b1 (smoothstep -0.2 0.2 bands))
               (b2 (smoothstep -0.2 0.2 (- bands 0.5)))
               (noise (vec3 (+ (* 0.4 (shd/noise:perlin (* (vec2 x y) 10)))
                               (* 0.7 (shd/noise:cellular (* (vec2 x y) 50)))
                               (* 0.3 (shd/noise:perlin-surflet
                                       (* (vec2 x y) 200))))))
               (noise (shd/color:color-filter noise
                                              (vec3 (sin x) (sin y) 0.5)
                                              1))
               (blend (+ (max (* b1 (- 1 b2)) (* ripples b2 waves))
                         (* waves 0.5 b2)))
               (blend (mix blend
                           (- 1 blend)
                           (smoothstep -0.5 0.5 (sin (+ (* x 2) time))))))
          (setf color (mix (vec3 blend) noise 0.5))))
      (vec4 color 1))))

(define-shader art3 ()
  (:vertex (shd/tex:unlit/vert-nil mesh-attrs))
  (:fragment (art3/frag)))

;;; Art 4
;;; A somewhat kaleidoscope-like effect with lots of knobs and whistles as
;;; uniforms. Intended to be used with other functions, such as mixing with a
;;; noise or texture pattern.

(define-function art4/hash ((p :vec2))
  (let* ((p (fract (vec3 (* p (vec2 385.18692 958.5519))
                         (* (+ (.x p) (.y p)) 534.3851))))
         (p (+ p (dot p (+ p 42.4112)))))
    (fract p)))

(define-function art4/xor ((a :float) (b :float))
  (+ (* a (- 1 b)) (* b (- 1 a))))

(define-function art4/frag (&uniform
                            (res :vec2)
                            (time :float)
                            ;; size of circles - [0, 1]
                            (zoom :float)
                            ;; multiplier for ripple speed - [-inf, inf]
                            (speed :float)
                            ;; strength of the overall effect - [0, 1]
                            (strength :float)
                            ;; randomly color each circle instead of monochrome
                            (colorize :bool)
                            ;; render circle outlines instead of filled
                            (outline :bool)
                            ;; amount of focus/detail - [0, 1]
                            (detail :float))
  (let* ((angle (/ (float pi) 4))
         (s (sin angle))
         (c (cos angle))
         (uv (* (/ (- (.xy gl-frag-coord) (* res 0.5)) (.y res))
                (mat2 c (- s) s c)))
         (cell-size (* uv (mix 100 1 (clamp zoom 0 1))))
         (cell-index (floor cell-size))
         (cell-color (if colorize (art4/hash cell-index) (vec3 1)))
         (grid-uv (- (fract cell-size) 0.5))
         (circle 0.0)
         (detail (clamp detail 0 1))
         (strength (mix 1.5 0.2 (clamp strength 0 1)))
         (speed (* time speed)))
    (dotimes (y 3)
      (dotimes (x 3)
        (let* ((offset (1- (vec2 x y)))
               (cell-origin (length (- grid-uv offset)))
               (distance (* (length (+ cell-index offset)) 0.3))
               (radius (mix strength 1.5 (+ (* (sin (- distance speed)) 0.5)
                                            0.5))))
          (setf circle (art4/xor
                        circle
                        (smoothstep radius (* radius detail) cell-origin))))))
    (let ((color (* cell-color (vec3 (mod circle (if outline 1 2))))))
      (vec4 color 1))))

(define-shader art4 ()
  (:vertex (shd/tex:unlit/vert-nil mesh-attrs))
  (:fragment (art4/frag)))

;;; Art 5
;;; Simulate rain/fog on glass

(define-function art5/hash ((n :float))
  (fract (* (sin (* n 51384.508)) 6579.492)))

(define-function art5/hash-1-3 ((n :float))
  (let* ((n (fract (* (vec3 n) (vec3 0.1031 0.11369 0.13787))))
         (n (+ n (dot n (+ (.yzx n) 19.19)))))
    (fract
     (vec3 (* (+ (.x n) (.y n)) (.z n))
           (* (+ (.x n) (.z n)) (.y n))
           (* (+ (.y n) (.z n)) (.x n))))))

(define-function art5/drop-layer-1 ((uv :vec2)
                                    (time :float))
  (let* ((uv (* uv 30.0))
         (id (floor uv))
         (uv (- (fract uv) 0.5))
         (n (art5/hash-1-3 (+ (* (.x id) 513.50877)
                              (* (.y id) 6570.492))))
         (p (* (- (.xy n) 0.5) 0.7))
         (d (length (- uv p)))
         (fade (fract (+ time (.z n))))
         (fade (* (smoothstep 0.0 0.02 fade) (smoothstep 1.0 0.02 fade))))
    (* (smoothstep 0.3 0.0 d)
       (fract (* (.z n) 10))
       fade)))

(define-function art5/drop-layer-2-3 ((uv :vec2)
                                      (time :float))
  (let* ((uv2 uv)
         (uv (+ uv (vec2 0 (* time 0.75))))
         (a (vec2 6 1))
         (grid (* a 2))
         (id (floor (* uv grid)))
         (uv (+ uv (vec2 0 (art5/hash (.x id)))))
         (id (floor (* uv grid)))
         (n (art5/hash-1-3 (+ (* (.x id) 101.87) (* (.y id) 41480.56))))
         (st (- (fract (* uv grid)) (vec2 0.5 0)))
         (x (- (.x n) 0.5))
         (y (* (.y uv2) 25))
         (wiggle (sin (+ y (sin y))))
         (x (* (+ x (* wiggle (- 0.5 (abs x)) (- (.z n) 0.5))) 0.5))
         (y-time (fract (+ (.z n) time)))
         (y (+ (* (- (* (smoothstep 0.0 0.85 y-time)
                        (smoothstep 1.0 0.85 y-time))
                     0.5)
                  0.9)
               0.5))
         (p (vec2 x y))
         (d (length (* (- st p) (.yx a))))
         (drop (smoothstep 0.4 0.0 d))
         (r (sqrt (smoothstep 1.0 y (.y st))))
         (cd (abs (- (.x st) x)))
         (trail-front (smoothstep -0.02 0.02 (- (.y st) y)))
         (trail (* (smoothstep (* r .23) (* r r 0.15) cd) trail-front r r))
         (y (.y uv2))
         (trail2 (smoothstep (* 0.2 r) 0.0 cd))
         (droplets (* (max 0 (- (sin (* y (- 1 y) 120)) (.y st)))
                      trail2
                      (.z n)))
         (y (+ (fract (* y 10)) (- (.y st) 0.5)))
         (droplets (smoothstep 0.3 0 (length (- st (vec2 x y))))))
    (vec2 (+ (* droplets r trail-front) drop) trail)))

(define-function art5/drops ((uv :vec2)
                             (time :float)
                             (layer1 :float)
                             (layer2 :float)
                             (layer3 :float))
  (let* ((s (* (art5/drop-layer-1 uv time) layer1))
         (m1 (* (art5/drop-layer-2-3 uv time) layer2))
         (m2 (* (art5/drop-layer-2-3 (* uv 1.85) time) layer3))
         (c (+ s (.x m1) (.x m2)))
         (c (smoothstep 0.3 1.0 c)))
    (vec2 c (max (* (.y m1) layer1) (* (.y m2) layer2)))))

(define-function art5/frag (&uniform
                            (time :float)
                            (res :vec2)
                            (blur :float)
                            (sampler :sampler-2d))
  (let* ((uv (/ (- (.xy gl-frag-coord) (* res 0.5)) (.y res)))
         (uv2 (/ (.xy gl-frag-coord) (.xy res)))
         (time (* time 0.24))
         (rain-amount (+ (* (sin (* time 0.05)) 0.3) 0.7))
         (blur (mix 3 blur rain-amount))
         (uv (* uv 0.7))
         (uv2 (+ (* (- uv2 0.5) 0.9) 0.5))
         (layer1 (* (smoothstep -0.5 1.0 rain-amount) 2.0))
         (layer2 (smoothstep 0.25 0.75 rain-amount))
         (layer3 (smoothstep 0.0 0.5 rain-amount))
         (c (art5/drops uv time layer1 layer2 layer3))
         (e (vec2 0.001 0))
         (cx (.x (art5/drops (+ uv e) time layer1 layer2 layer3)))
         (cy (.x (art5/drops (+ uv (.yx e)) time layer1 layer2 layer3)))
         (n (vec2 (- cx (.x c)) (- cy (.x c))))
         (focus (mix (- blur (.y c)) 2.0 (smoothstep 0.1 0.2 (.x c)))))
    (vec4 (.rgb (texture-lod sampler (+ uv2 n) focus)) 1)))

(define-shader art5 ()
  (:vertex (shd/tex:unlit/vert-nil mesh-attrs))
  (:fragment (art5/frag)))
