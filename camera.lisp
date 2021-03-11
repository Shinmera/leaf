(in-package #:org.shirakumo.fraf.kandria)

(defclass camera (trial:2d-camera unpausable)
  ((flare:name :initform :camera)
   (scale :initform 1.0 :accessor view-scale)
   (target-size :initarg :target-size :accessor target-size)
   (target :initarg :target :initform NIL :accessor target)
   (intended-location :initform (vec2 0 0) :accessor intended-location)
   (zoom :initarg :zoom :initform 1.0 :accessor zoom)
   (intended-zoom :initform 1.0 :accessor intended-zoom)
   (chunk :initform NIL :accessor chunk)
   (shake-timer :initform 0f0 :accessor shake-timer)
   (shake-intensity :initform 3 :accessor shake-intensity)
   (shake-unique :initform 0 :accessor shake-unique)
   (shake-controller-multiplier :initform 1.0 :accessor shake-controller-multiplier)
   (offset :initform (vec 0 0) :accessor offset))
  (:default-initargs
   :location (vec 0 0)
   :target-size (v* +tiles-in-view+ +tile-size+ .5)))

(defmethod enter :after ((camera camera) (scene scene))
  (setf (target camera) (unit 'player scene))
  (when (target camera)
    (setf (location camera) (vcopy (location (target camera))))))

(defun clamp-camera-target (camera target)
  (let ((chunk (chunk camera))
        (zoom (max (zoom camera) (intended-zoom camera))))
    (when chunk
      (let ((lx (vx2 (location chunk)))
            (ly (vy2 (location chunk)))
            (lw (vx2 (bsize chunk)))
            (lh (vy2 (bsize chunk)))
            (cw (/ (vx2 (target-size camera)) zoom))
            (ch (/ (vy2 (target-size camera)) zoom)))
        (setf (vx target) (clamp (+ lx cw (- lw))
                                 (vx target)
                                 (+ lx (- cw) lw)))
        (setf (vy target) (clamp (+ ly ch (- lh))
                                 (vy target)
                                 (+ ly (- ch) lh)))))))

(defmethod handle :before ((ev tick) (camera camera))
  (unless (find-panel 'editor)
    (let ((loc (location camera)))
      ;; Camera movement
      (let ((int (intended-location camera)))
        (when (target camera)
          (let ((tar (location (target camera))))
            (vsetf int (vx tar) (vy tar))))
        (clamp-camera-target camera int)
        (let* ((dir (v- int loc))
               (len (max 1 (vlength dir)))
               (ease (clamp 0 (+ 0.2 (/ (expt len 1.5) 100)) 20)))
          (nv* dir (/ ease len))
          (nv+ loc dir)))
      ;; Camera zoom
      (let* ((z (zoom camera))
             (int (intended-zoom camera))
             (dir (/ (- (log int) (log z)) 10)))
        (cond ((< (abs dir) 0.001)
               (setf (zoom camera) int))
              (T
               (incf (zoom camera) dir)
               (clamp-camera-target camera loc))))
      ;; Camera shake
      (when (< 0 (shake-timer camera))
        (decf (shake-timer camera) (dt ev))
        (dolist (device (gamepad:list-devices))
          (gamepad:rumble device (if (< 0 (shake-timer camera))
                                     (* 100 (dt ev) (shake-controller-multiplier camera) (shake-intensity camera))
                                     0)))
        ;; Deterministic shake so that we can slow it down properly.
        (let ((frame-id (sxhash (+ (shake-unique camera) (mod (floor (* (shake-timer camera) 100)) 100)))))
          (nv+ loc (polar->cartesian (vec (* (logand #xFF (1+ frame-id)) (shake-intensity camera) 0.001)
                                          (* (logand #xFF frame-id) (/ (* 2 PI) #xFF))))))
        (clamp-camera-target camera loc))
      (let ((off (offset camera)))
        (when (v/= 0 off)
          (nv+ loc off)
          (nv* off 0.9)
          (when (< (abs (vx off)) 0.1) (setf (vx off) 0f0))
          (when (< (abs (vy off)) 0.1) (setf (vy off) 0f0))
          (clamp-camera-target camera loc))))))

(defmethod (setf zoom) :after (zoom (camera camera))
  (setf (view-scale camera) (float (/ (width *context*) (* 2 (vx (target-size camera)))))))

(defmethod snap-to-target ((camera camera) target)
  (setf (target camera) target)
  (setf (location camera) (vcopy (location target)))
  (clamp-camera-target camera (location camera)))

(defmethod (setf target) :after ((target game-entity) (camera camera))
  (setf (chunk camera) (find-containing target (region +world+))))

(defmethod handle :before ((ev resize) (camera camera))
  ;; Ensure we scale to fit width as much as possible without showing space
  ;; outside the chunk.
  (let* ((optimal-scale (float (/ (width ev) (* 2 (vx (target-size camera))))))
         (max-fit-scale (if (chunk camera) (/ (height ev) (vy (bsize (chunk camera))) 2) optimal-scale))
         (scale (max optimal-scale max-fit-scale)))
    (setf (view-scale camera) scale)
    (setf (vy (target-size camera)) (/ (height ev) scale 2))))

(defmethod (setf chunk) :after (chunk (camera camera))
  ;; Optimal bounds might have changed, update.
  (handle (make-instance 'resize :width (width *context*) :height (height *context*)) camera))

(defmethod handle ((ev switch-chunk) (camera camera))
  (setf (chunk camera) (chunk ev)))

(defmethod handle ((ev switch-region) (camera camera))
  (setf (target camera) (unit 'player T)))

(defmethod handle ((ev window-shown) (camera camera))
  (if (target camera)
      (snap-to-target camera (target camera))
      (vsetf (location camera) 0 0)))

(defmethod project-view ((camera camera))
  (let* ((z (max 0.0001 (* (view-scale camera) (zoom camera))))
         (v (nv- (v/ (target-size camera) (zoom camera)) (location camera))))
    (reset-matrix *view-matrix*)
    (scale-by z z z *view-matrix*)
    (translate-by (vx v) (vy v) 100 *view-matrix*)))

(defun shake-camera (&key (duration 0.2) (intensity 3) (controller-multiplier 1.0))
  (let ((camera (unit :camera +world+)))
    (setf (shake-unique camera) (random 100))
    (setf (shake-timer camera) duration)
    (setf (shake-intensity camera) (* (setting :gameplay :screen-shake) intensity))
    (setf (shake-controller-multiplier camera) controller-multiplier)))

(defun duck-camera (&key (offset (vec 0 -4)))
  (nv+ (offset (unit :camera +world+)) offset))

(defun in-view-p (loc bsize)
  (let* ((camera (unit :camera T)))
    (let ((- (vec 0 0))
          (+ (vec (width *context*) (height *context*)))
          (off (v/ (target-size camera) (zoom camera))))
      (nv- (nv+ (nv/ - (view-scale camera) (zoom camera)) (location camera)) off)
      (nv- (nv+ (nv/ + (view-scale camera) (zoom camera)) (location camera)) off)
      (and (< (vx -) (+ (vx loc) (vx bsize)))
           (< (- (vx loc) (vx bsize)) (vx +))
           (< (- (vy loc) (vy bsize)) (vy +))
           (< (vy -) (+ (vy loc) (vy bsize)))))))
