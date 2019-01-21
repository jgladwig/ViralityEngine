(in-package :first-light.components)

(defclass transform-state ()
  ((%current :accessor current
             :initarg :current)
   (%incremental :accessor incremental
                 :initarg :incremental)
   (%incremental-delta :accessor incremental-delta
                       :initarg :incremental-delta)
   (%previous :accessor previous
              :initarg :previous)
   (%interpolated :accessor interpolated
                  :initarg :interpolated)))

(defclass transform-state-vector (transform-state)
  ()
  (:default-initargs :current (m:vec3)
                     :incremental (m:vec3)
                     :incremental-delta (m:vec3)
                     :previous (m:vec3)
                     :interpolated (m:vec3)))

(defclass transform-state-quaternion (transform-state)
  ()
  (:default-initargs :current (m:quat 1)
                     :incremental (m:quat 1)
                     :incremental-delta (m:quat 1)
                     :previous (m:quat 1)
                     :interpolated (m:quat 1)))

(defun make-translation-state ()
  (make-instance 'transform-state-vector))

(defun make-rotation-state ()
  (make-instance 'transform-state-quaternion
                 :incremental (m:vec3)
                 :incremental-delta (m:vec3)))

(defun make-scaling-state ()
  (make-instance 'transform-state-vector
                 :current (m:vec3 1)))

(defun interpolate-vector (state factor)
  (m:lerp (previous state) (current state) factor (interpolated state)))

(defun interpolate-quaternion (state factor)
  (m:slerp (previous state) (current state) factor (interpolated state)))

(define-component transform ()
  ((parent :default nil)
   (children :default nil)
   (translation :default (make-translation-state))
   (rotation :default (make-rotation-state))
   (scaling :default (make-scaling-state))
   (local :default (m:mat4 1))
   (model :default (m:mat4 1))))

(defun transform-add-child (parent child)
  (push child (children parent))
  (setf (parent child) parent))

(defun transform-remove-child (parent child)
  (setf (children parent) (remove-if (lambda (x) (eq x child)) (children parent))
        (parent child) nil))

(defun transform-node (core-state node)
  (let ((delta (delta (context core-state))))
    (with-slots (%previous %current %incremental-delta %incremental) (scaling node)
      (m:copy-into %previous %current)
      (m:+ %current (m:* %incremental delta %incremental-delta) %current))
    (with-slots (%previous %current %incremental-delta %incremental) (rotation node)
      (m:copy-into %previous %current)
      (m:rotate :local %current
                  (m:* %incremental delta %incremental-delta) %current))


    (with-slots (%previous %current %incremental-delta %incremental) (translation node)
      (m:copy-into %previous %current)
      (m:+ %current (m:* %incremental delta %incremental-delta) %current))))

(defun resolve-local (node alpha)
  (with-slots (%local %scaling %rotation %translation) node
    (interpolate-vector %scaling alpha)
    (interpolate-quaternion %rotation alpha)
    (interpolate-vector %translation alpha)
    (m:* (m:mat4 (interpolated %rotation) %local)
           (m:set-scale m:+id-mat4+ (interpolated %scaling))
           %local)
    (m:set-translation %local (interpolated %translation) %local)))

(defun resolve-model (node alpha)
  (u:when-let ((parent (parent node)))
    (resolve-local node alpha)
    (m:* (model parent) (local node) (model node))))

(defun map-nodes (func parent)
  (funcall func parent)
  (dolist (child (children parent))
    (map-nodes func child)))

(defun interpolate-transforms (core-state)
  (map-nodes
   (lambda (node)
     (resolve-model node (%fl::alpha (%fl:frame-manager core-state))))
   (actor-component-by-type (%fl:scene-tree core-state) 'transform)))

(defmethod make-component (context (component-type (eql 'transform)) &rest args)
  (let ((instance (make-instance component-type :type component-type :context context)))
    (apply #'reinitialize-instance instance args)
    instance))

(defmethod reinitialize-instance ((instance transform)
                                  &key
                                    actor
                                    (translate (m:vec3))
                                    (translate/inc (m:vec3))
                                    (rotate (m:vec3))
                                    (rotate/inc (m:vec3))
                                    (scale (m:vec3 1))
                                    (scale/inc (m:vec3)))
  (with-slots (%translation %rotation %scaling) instance
    (setf (actor instance) actor
          (state instance) :initialize
          (current %translation) translate
          (previous %translation) (m:copy translate)
          (incremental %translation) translate/inc
          (current %rotation) (etypecase rotate
                                (m:vec3 (m:rotate :local m:+id-quat+ rotate))
                                (m:quat rotate))
          (previous %rotation) (m:copy (current %rotation))
          (incremental %rotation) rotate/inc
          (current %scaling) scale
          (previous %scaling) (m:copy scale)
          (incremental %scaling) scale/inc)))

;;; User protocol

(defun %rotate/model-space (rotation vec &optional replace-p instant-p)
  (with-accessors ((previous previous) (current current)) rotation
    (m:rotate :local (if replace-p m:+id-quat+ current) vec current)
    (when instant-p
      (m:copy-into previous current))))

(defun %rotate/world-space (rotation vec &optional replace-p instant-p)
  (declare (ignore rotation vec replace-p instant-p))
  (error "ROTATE not yet implemented for world space."))

(defun rotate (transform vec &key (space :model) replace-p instant-p)
  (ecase space
    (:model (%rotate/model-space (rotation transform) vec replace-p instant-p))
    (:world (%rotate/world-space (rotation transform) vec replace-p instant-p))))

(defun %translate/model-space (translation vec &optional replace-p instant-p)
  (with-accessors ((previous previous) (current current)) translation
    (m:+ (if replace-p m:+zero-vec3+ current) vec current)
    (when instant-p
      (m:copy-into previous current))))

(defun %translate/world-space (translation vec &optional replace-p instant-p)
  (declare (ignore translation vec replace-p instant-p))
  (error "TRANSLATE not yet implemented for world space."))

(defun translate (transform vec &key (space :model) replace-p instant-p)
  (ecase space
    (:model (%translate/model-space (translation transform) vec replace-p instant-p))
    (:world (%translate/world-space (translation transform) vec replace-p instant-p))))

(defun scale (transform vec &key replace-p instant-p)
  (with-accessors ((previous previous) (current current)) (scaling transform)
    (m:+ (if replace-p m:+zero-vec3+ current) vec current)
    (when instant-p
      (m:copy-into previous current))))
