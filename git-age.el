;;; git-age.el --- Highlight recent Git modifications and commit line footprint -*- lexical-binding: t; -*-

;; Author: Vaishnav Katiyar
;; Version: 0.1
;; Package-Requires: ((emacs "25.1"))
;; Keywords: git, vc, age, highlight, blame
;; URL: https://github.com/vaishnavkatiyar/git-age.el

;;; Commentary:

;; This package highlights lines in a buffer based on how recently they were
;; last modified, using Git blame data. It also annotates each line with the
;; number of total lines in the buffer introduced by the same commit.
;;
;; This is useful for understanding:
;; - Which parts of the code are recently touched or added
;; - Which commits still have a large footprint in the current file
;;
;; Note: This does not detect high churn in the traditional sense
;; (i.e., lines that change frequently over time), but rather focuses on age
;; and persistence of changes across commits.

;;; Code:

(defun git-age--blame-output ()
  "Run git blame and return the output as a string for the current buffer."
  (let ((file (buffer-file-name)))
    (when (and file (vc-backend file))
      (shell-command-to-string
       (format "git blame --line-porcelain %s" (shell-quote-argument file))))))

(defun git-age--parse-blame (output)
  "Parse git blame OUTPUT and return a list of (line-number . (commit . timestamp))."
  (let ((lines (split-string output "\n"))
        (results '())
        (commit nil)
        (timestamp nil)
        (line-number 1))
    (dolist (line lines)
      (cond
       ((string-match "^\\([0-9a-f]+\\) " line)
        (when (and commit timestamp)
          (push (cons line-number (cons commit timestamp)) results)
          (setq line-number (1+ line-number)))
        (setq commit (match-string 1 line)))
       ((string-prefix-p "author-time " line)
        (setq timestamp (string-to-number (substring line 12))))))
    (when (and commit timestamp)
      (push (cons line-number (cons commit timestamp)) results))
    (reverse results)))

(defun git-age--calculate-scores (blame-data)
  "Return list of (line-number score count) from BLAME-DATA.
Score ranges from 0.0 (oldest) to 1.0 (most recent) based on commit age."
  (let* ((now (float-time))
         (ages (mapcar (lambda (p) (- now (cdr (cdr p)))) blame-data))
         (max-age (apply #'max ages))
         (min-age (apply #'min ages))
         (commit-counts (make-hash-table :test 'equal))
         (scored-lines '())
         (max-age-line nil)
         (min-age-line nil))

    (dolist (entry blame-data)
      (let ((commit (car (cdr entry))))
        (puthash commit (1+ (gethash commit commit-counts 0)) commit-counts)))

    (dolist (pair blame-data)
      (let* ((line (car pair))
             (commit (car (cdr pair)))
             (time (cdr (cdr pair)))
             (age (- now time))
             (score (if (<= max-age min-age)
                        1.0
                      (- 1.0 (/ (- age min-age) (- max-age min-age)))))
             (count (gethash commit commit-counts))
             (entry (list line score count commit time age)))
        (when (or (not max-age-line) (> age (nth 5 max-age-line)))
          (setq max-age-line entry))
        (when (or (not min-age-line) (< age (nth 5 min-age-line)))
          (setq min-age-line entry))
        (let* ((age-days (/ age 86400.0))
               (human-time (format-time-string "%Y-%m-%d %H:%M" (seconds-to-time time))))
          (message "Line %d → commit: %s, date: %s, age: %.1f days (%.1f yrs), score: %.4f, commit line count: %d"
                   line commit human-time age-days (/ age-days 365.25) score count))
        (push entry scored-lines)))

    (cl-labels ((format-entry (entry)
                  (let* ((commit (nth 3 entry))
                         (time (nth 4 entry))
                         (age (/ (nth 5 entry) 86400.0))
                         (score (nth 1 entry))
                         (count (nth 2 entry))
                         (date (format-time-string "%Y-%m-%d %H:%M" (seconds-to-time time))))
                    (format "commit: %s, date: %s, age: %.1f days (%.1f yrs), score: %.4f, commit line count: %d"
                            commit date age (/ age 365.25) score count))))
      (message "OLDEST → %s" (format-entry max-age-line))
      (message "NEWEST → %s" (format-entry min-age-line)))

    (mapcar (lambda (e) (list (nth 0 e) (nth 1 e) (nth 2 e))) (reverse scored-lines))))

(defun git-age--score-color (score)
  "Map SCORE in [0,1] to a red-green heatmap color."
  (let* ((clamped (max 0.0 (min 1.0 score)))
         (red (floor (* clamped 255)))
         (green (floor (* (- 1.0 clamped) 255))))
    (format "#%02x%02x00" red green)))

(defun git-age--highlight-lines (score-data)
  "Highlight buffer lines based on SCORE-DATA: (line score count)."
  (save-excursion
    (git-age-clear-overlays)
    (dolist (item score-data)
      (let* ((line (nth 0 item))
             (score (nth 1 item))
             (count (nth 2 item))
             (color (git-age--score-color score)))
        (goto-char (point-min))
        (forward-line (1- line))
        (let ((overlay (make-overlay (line-beginning-position) (line-end-position))))
          (overlay-put overlay 'face `(:background ,color))
          (overlay-put overlay 'git-age t))
        (let ((eol (line-end-position))
              (count-text (format "  ⟶ %dx" count)))
          (let ((suffix-ov (make-overlay eol eol)))
            (overlay-put suffix-ov 'after-string
                         (propertize count-text
                                     'face '(:foreground "gray70" :slant italic)))
            (overlay-put suffix-ov 'git-age t)))))))

;;;###autoload
(defun git-age-visualize-buffer ()
  "Highlight current buffer based on recent Git changes (age)."
  (interactive)
  (let* ((output (git-age--blame-output)))
    (if (not output)
        (message "Git blame data not available for this buffer.")
      (let* ((parsed (git-age--parse-blame output))
             (scored (git-age--calculate-scores parsed)))
        (message "Highlighted %d lines..." (length scored))
        (git-age--highlight-lines scored)))))

;;;###autoload
(defun git-age-clear-overlays ()
  "Clear Git age highlights from buffer."
  (interactive)
  (remove-overlays (point-min) (point-max) 'git-age t))

(provide 'git-age)

;;; git-age.el ends here