(in-package #:com.liutos.cl-github-page.storage)

(defun delete-by-alist (alist table)
  (let (query
        where-part)
    (setf where-part
          (encode-sql-alist-to-string alist
                                      :separator " AND "))
    (setf query
          (format nil "DELETE FROM `~A` WHERE ~A" table where-part))
    (query query)))

(defun encode-sql-alist-to-string (alist
                                   &key
                                     (separator ", "))
  (let ((is-empty t))
    (with-output-to-string (sql)
      (dolist (element alist)
        (destructuring-bind (col-name . expr) element
          (when expr
            (when (not is-empty)
              (write-string separator sql))
            (let (part)
              (setf part (format nil "`~A` = ~S" col-name expr))
              (write-string part sql)
              (setf is-empty nil))))))))

(defun insert-one-row (alist table)
  (let (query
        set-part)
    (setf set-part
          (encode-sql-alist-to-string alist))
    (setf query
          (format nil "INSERT INTO `~A` SET ~A" table set-part))
    (query query)))

(defun make-plist-from-rows (result-set)
  (let ((fields (cadar result-set))
        (rows (caar result-set)))
    (mapcar #'(lambda (row)
                (mapcan #'(lambda (field expr)
                            (list (intern (string-upcase (car field)) :keyword)
                                  expr))
                        fields
                        row))
            rows)))

(defun update-by-id (alist id table)
  (let (query
        set-part)
    (setf set-part
          (encode-sql-alist-to-string alist))
    (setf query
          (format nil "UPDATE `~A` SET ~A WHERE `~A_id` = ~D" table set-part table id))
    (query query)))

;;; EXPORT

(defun bind-category-post (category-id post-id)
  (insert-one-row `(("category_id" . ,category-id)
                    ("post_id" . ,post-id))
                  "category_post"))

(defun bind-post-tag (post-id tag-id)
  (insert-one-row `(("post_id" . ,post-id)
                    ("tag_id" . ,tag-id))
                  "post_tag"))

(defun create-category (name)
  (insert-one-row `(("name" . ,name)) "category"))

(defun create-friend (title url)
  "创建一条友情链接"
  (check-type title string)
  (check-type url string)
  (insert-one-row `(("title" . ,title)
                    ("url" . ,url))
                  "friend"))

(defun create-post (body is-active source title
                    &key
                      author
                      post-id
                      write-at)
  (let ((alist `(("author" . ,author)
                 ("body" . ,body)
                 ("create_at" . ,(make-datetime-of-now))
                 ("is_active" . ,is-active)
                 ("source" . ,source)
                 ("title" . ,title)
                 ("update_at" . ,(make-datetime-of-now))
                 ("write_at" . ,(or write-at (make-datetime-of-now))))))
    (when post-id
      (push (cons "post_id" post-id) alist))
    (insert-one-row alist "post")))

(defun create-tag (name)
  (insert-one-row `(("name" . ,name)) "tag"))

(defun delete-post (post-id)
  (delete-by-alist `(("post_id" . ,post-id))
                   "post"))

(defun find-category (category-id)
  "查找给定的分类"
  (check-type category-id integer)
  (let* ((query (format nil "SELECT * FROM `category` WHERE `category_id` = ~D" category-id))
         (result-set (query query)))
    (car (make-plist-from-rows result-set))))

(defun find-category-by-name (name)
  (let* ((query (format nil "SELECT * FROM `category` WHERE `name` = ~S" name))
         (result-set (query query)))
    (car (make-plist-from-rows result-set))))

(defun find-category-post-binding (category-id post-id)
  "查询分类与文章的绑定"
  (check-type category-id integer)
  (check-type post-id integer)
  (let* ((query (format nil "SELECT * FROM `category_post` WHERE `category_id` = ~D AND `post_id` = ~D"
                        category-id post-id))
         (result-set (query query)))
    (car (make-plist-from-rows result-set))))

(defun find-max-post-id ()
  "Return the largest post's id found in database."
  (let ((query "SELECT MAX(`post_id`) AS `post_id` FROM `post`"))
    (let ((row (car (make-plist-from-rows (query query)))))
      (getf row :post_id))))

(defun find-next-post (post-id)
  (let* ((query (format nil "SELECT * FROM `post` WHERE `post_id` > ~D ORDER BY `post_id` ASC LIMIT 1" post-id))
         (result-set (query query)))
    (car (make-plist-from-rows result-set))))

(defun find-post (post-id)
  (let (query
        result-set)
    (setf query
          (format nil "SELECT * FROM `post` WHERE `post_id` = ~D" post-id))
    (setf result-set
          (query query))
    (car (make-plist-from-rows result-set))))

(defun find-post-by-category (category-id)
  "查询绑定到指定分类下的文章"
  (let* ((query (format nil "SELECT * FROM `post` LEFT JOIN `category_post` ON `post`.`post_id` = `category_post`.`post_id` WHERE `category_post`.`category_id` = ~D" category-id))
         (result-set (query query)))
    (make-plist-from-rows result-set)))

(defun find-post-by-source (source)
  (let (query
        result-set)
    (setf query
          (format nil "SELECT * FROM `post` WHERE `source` = ~S LIMIT 1" source))
    (setf result-set
          (query query))
    (caaar result-set)))

(defun find-prev-post (post-id)
  (let* ((query (format nil "SELECT * FROM `post` WHERE `post_id` < ~D ORDER BY `post_id` DESC LIMIT 1" post-id))
         (result-set (query query)))
    (car (make-plist-from-rows result-set))))

(defun get-category-list ()
  "获取所有的分类"
  (let* ((query (format nil "SELECT * FROM `category`"))
         (result-set (query query)))
    (make-plist-from-rows result-set)))

(defun get-friend-list ()
  "获取所有的友情链接"
  (let* ((query (format nil "SELECT * FROM `friend`"))
         (result-set (query query)))
    (make-plist-from-rows result-set)))

(defun get-post-list ()
  (let* ((query (format nil "SELECT * FROM `post` ORDER BY `write_at` DESC"))
         (result-set (query query)))
    (make-plist-from-rows result-set)))

(defun start ()
  (apply #'connect (com.liutos.cl-github-page.config:get-database-options))
  (query "SET NAMES utf8"))

(defun stop ()
  (disconnect))

(defun unbind-category-post (category-id post-id)
  (delete-by-alist `(("category_id" . ,category-id)
                     ("post_id" . ,post-id))
                   "category_post"))

(defun unbind-post-tag (post-id tag-id)
  (delete-by-alist `(("post_id" . ,post-id)
                     ("tag_id" . ,tag-id))
                   "post_tag"))

(defun update-category (category-id
                        &key
                          name)
  (update-by-id `(("name" . ,name)) category-id "category"))

(defun update-post (post-id
                    &key
                      author
                      body
                      build-at
                      is-active
                      source
                      title
                      write-at)
  (update-by-id `(("author" . ,author)
                  ("body" . ,body)
                  ("build_at" . ,build-at)
                  ("is_active" . ,is-active)
                  ("source" . ,source)
                  ("title" . ,title)
                  ("update_at" . ,(make-datetime-of-now))
                  ("write_at" . ,write-at))
                post-id
                "post"))

(defun update-tag (tag-id
                   &key
                     name)
  (update-by-id `(("name" . ,name)) tag-id "tag"))
