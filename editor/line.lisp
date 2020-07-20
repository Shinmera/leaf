(in-package #:org.shirakumo.fraf.leaf)

(defclass line (tool)
  ((start :initform NIL :accessor start)
   (existing :initform NIL :accessor existing)))

(defmethod label ((tool line)) "Line")

(defmethod handle ((event mouse-press) (tool line))
  (setf (state tool) (case (button event)
                       (:left :placing)
                       (:right :erasing)))
  (setf (start tool) (vcopy (pos event))))

(defmethod handle ((event mouse-release) (tool line))
  (let ((chunk (entity tool))
        (a (start tool))
        (b (vcopy (pos event)))
        (existing (existing tool)))
    (flet ((redo (_)
             (paint-line chunk a b))
           (undo (_)
             (paint-line chunk a b :tiles existing)))
      (commit (make-instance 'closure-action :redo #'redo :undo #'undo) tool)))
  (setf (state tool) NIL)
  (setf (existing tool) NIL))

(defmethod handle ((event mouse-move) (tool line))
  (case (state tool)
    (:placing
     (paint-line (entity tool) (start tool) (old-pos event) :tiles (existing tool))
     (setf (existing tool) (paint-line (entity tool) (start tool) (pos event))))
    (:erasing
     (paint-line (entity tool) (start tool) (old-pos event) :tiles (existing tool))
     (setf (existing tool) (paint-line (entity tool) (start tool) (pos event) :tiles '#1=(#.(vec 0 0) . #1#))))))

(defun paint-line (chunk start end &key tiles)
  (let* ((a (mouse-tile-pos start))
         (b (mouse-tile-pos end))
         (existing ()))
    (labels ((set-tile (tile)
               (push (tile a chunk) existing)
               (setf (tile a chunk) (if tiles (pop tiles) (vec tile 0)))))
      (loop for deg = (atan (- (vy b) (vy a)) (- (vx b) (vx a)))
            do (set-tile 1)
               (cond ((= deg (atan 1 3)) ;; 3-tile slope
                      (incf (vy a) +tile-size+)
                      (set-tile 10)
                      (incf (vx a) +tile-size+)
                      (set-tile 11)
                      (incf (vx a) +tile-size+)
                      (set-tile 12)
                      (incf (vx a) +tile-size+))
                     ((= deg (atan 1 2)) ;; 2-tile slope
                      (incf (vy a) +tile-size+)
                      (set-tile 6)
                      (incf (vx a) +tile-size+)
                      (set-tile 7)
                      (incf (vx a) +tile-size+))
                     ((= deg (atan 1 1)) ;; 1-tile slope
                      (incf (vy a) +tile-size+)
                      (set-tile 4)
                      (incf (vx a) +tile-size+))
                     ((= deg (atan 1 -1)) ;; 1-tile slope
                      (incf (vy a) +tile-size+)
                      (set-tile 5)
                      (decf (vx a) +tile-size+))
                     ((= deg (atan 1 -2)) ;; 2-tile slope
                      (incf (vy a) +tile-size+)
                      (set-tile 9)
                      (decf (vx a) +tile-size+)
                      (set-tile 8)
                      (decf (vx a) +tile-size+))
                     ((= deg (atan 1 -3)) ;; 3-tile slope
                      (incf (vy a) +tile-size+)
                      (set-tile 15)
                      (decf (vx a) +tile-size+)
                      (set-tile 14)
                      (decf (vx a) +tile-size+)
                      (set-tile 13)
                      (decf (vx a) +tile-size+))
                     ((= (vx a) (vx b))
                      (incf (vy a) (* (signum (- (vy b) (vy a))) +tile-size+)))
                     (T
                      (incf (vx a) (* (signum (- (vx b) (vx a))) +tile-size+))))
            until (v= a b))
      (set-tile 1)
      (nreverse existing))))

