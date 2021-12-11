;; Minimum viable Hy REPL interaction
;; Relies on hy-mode package


(progn (require 'hy-shell)
       (require 'hy-mode))


(defun run-hy-dumbrepl ()
  (interactive)
  (let* ((venv (if current-prefix-arg
                   (read-directory-name "Venv directory:")
                 (file-truename "venv")))
         (venv-activate (if (file-exists-p venv)
                            (progn (message "Using venv: %s" venv)
                                   (format ". $(find %s -iname activate); "
                                           venv))
                          "")))
    (let ((buffer "*Hy*"))
      (make-comint-in-buffer
       hy-shell--name
       buffer
       "bash"
       nil
       "-c"
       (format ". ~/.bashrc; %s hy --repl-output-fn=hy.contrib.hy-repr.hy-repr -i '(require [hy.contrib.walk [let]])'"
               venv-activate))
      (switch-to-buffer buffer)
      (inferior-hy-mode))))


(defun hy-repl-set-repl-buffer (&optional buffer)
  (interactive "bREPL buffer: ")
  (setq buffer (or buffer "*Hy*"))
  (setq-local hy-repl-buffer buffer))


(add-hook 'hy-mode-hook 'hy-repl-set-repl-buffer)
(add-hook 'inferior-hy-mode-hook
          '(lambda ()
             (hy-repl-set-repl-buffer (current-buffer))))


(defun hy-repl-submit-input ()
  (with-current-buffer hy-repl-buffer
    (save-excursion
      (goto-char (point-max))
      (comint-skip-input)
      (comint-send-input))))


(defun hy-repl-send-region (&rest bounds)
  (interactive)
  (apply #'comint-send-region
         (cons (get-buffer-process hy-repl-buffer)
               (cond
                (bounds (list (car bounds)
                              (cadr bounds)))
                ((use-region-p) (list (region-beginning)
                                      (region-end)))
                (t (list (point-min)
                         (point-max))))))
  (hy-repl-submit-input))


(defun hy-repl-send-last-sexp ()
  (interactive)
  (let ((b (point))
        (e (save-excursion
             (backward-sexp)
             (point))))
    (hy-repl-send-region b e)))


(defun hy-repl-inspect-symbol-at-point (format-string)
  (let ((sap (symbol-at-point)))
    (when sap
      (let* ((symbol (symbol-name sap))
             (payload (format format-string symbol)))
        (comint-send-string
         (get-buffer-process hy-repl-buffer)
         payload)
        (hy-repl-submit-input)))))


(defun hy-repl-help-symbol-at-point ()
  (interactive)
  (hy-repl-inspect-symbol-at-point "(help %s)"))


(defun hy-repl-dir-symbol-at-point ()
  (interactive)
  (hy-repl-inspect-symbol-at-point "(dir %s)"))


(progn (define-key repls-map (kbd "h") 'run-hy-dumbrepl)
       (dolist (x '(("C-x C-e" hy-repl-send-last-sexp)
                    ("C-c e r" hy-repl-send-region)
                    ("C-c e b" hy-repl-set-repl-buffer)
                    ("C-c ." hy-repl-help-symbol-at-point)
                    ("C-c /" hy-repl-dir-symbol-at-point)))
         (define-key hy-mode-map (kbd (car x)) (cadr x))
         (define-key inferior-hy-mode-map (kbd (car x)) (cadr x))))
