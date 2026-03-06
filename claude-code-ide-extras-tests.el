;;; claude-code-ide-extras-tests.el --- Tests for claude-code-ide-extras  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Piotr Kwiecinski

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Test suite for claude-code-ide-extras.el using ERT.
;;
;; Run tests with:
;;   emacs -batch -L . -l ert -l claude-code-ide-extras-tests.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)

;; Mock claude-code-ide dependencies before loading extras
(defvar claude-code-ide-buffer-name-function
  (lambda (dir)
    (format "*claude-code[%s]*" (file-name-nondirectory (directory-file-name dir)))))

(defvar claude-code-ide--processes (make-hash-table :test 'equal))

(defun claude-code-ide--get-working-directory ()
  "Mock: return current project directory."
  default-directory)

(defun claude-code-ide--get-process (&optional directory)
  "Mock: return process for DIRECTORY."
  (gethash (or directory default-directory) claude-code-ide--processes))

(defun claude-code-ide--display-buffer-in-side-window (_buffer)
  "Mock: display BUFFER in side window."
  nil)

(provide 'claude-code-ide)

(require 'claude-code-ide-extras)

;;; Helpers

(defun claude-code-ide-extras-tests--clear-processes ()
  "Clear all registered processes."
  (clrhash claude-code-ide--processes))

;;; Tests

(ert-deftest claude-code-ide-extras-test-close-visible-sessions ()
  "Test that visible Claude windows are closed."
  (claude-code-ide-extras-tests--clear-processes)
  (unwind-protect
      (let* ((buf1 (get-buffer-create "*claude-code[project1]*"))
             (buf2 (get-buffer-create "*claude-code[project2]*"))
             (deleted-windows '())
             (mock-process 'mock-process))
        (puthash "/dir/project1" mock-process claude-code-ide--processes)
        (puthash "/dir/project2" mock-process claude-code-ide--processes)
        (cl-letf (((symbol-function 'get-buffer-window)
                   (lambda (buf)
                     (cond
                      ((eq buf buf1) 'win1)
                      ((eq buf buf2) nil)
                      (t nil))))
                  ((symbol-function 'delete-window)
                   (lambda (win) (push win deleted-windows))))
          (claude-code-ide-extras--close-visible-sessions)
          (should (member 'win1 deleted-windows))
          (should (= (length deleted-windows) 1)))
        (kill-buffer buf1)
        (kill-buffer buf2))
    (claude-code-ide-extras-tests--clear-processes)))

(ert-deftest claude-code-ide-extras-test-on-context-switch-shows-session ()
  "Test that switching to a project with a session displays its buffer."
  (claude-code-ide-extras-tests--clear-processes)
  (unwind-protect
      (let* ((project-dir "/test/project/")
             (buf (get-buffer-create "*claude-code[project]*"))
             (mock-process (start-process "mock-live" nil "sleep" "60"))
             (displayed-buffer nil))
        (puthash project-dir mock-process claude-code-ide--processes)
        (cl-letf (((symbol-function 'claude-code-ide--get-working-directory)
                   (lambda () project-dir))
                  ((symbol-function 'claude-code-ide-extras--close-visible-sessions)
                   (lambda () nil))
                  ((symbol-function 'process-live-p)
                   (lambda (proc) (eq proc mock-process)))
                  ((symbol-function 'claude-code-ide--display-buffer-in-side-window)
                   (lambda (buf) (setq displayed-buffer buf))))
          (claude-code-ide-extras--on-context-switch)
          (should (eq displayed-buffer buf)))
        (delete-process mock-process)
        (kill-buffer buf))
    (claude-code-ide-extras-tests--clear-processes)))

(ert-deftest claude-code-ide-extras-test-on-context-switch-closes-windows-no-session ()
  "Test that switching to a project without a session closes visible Claude windows."
  (claude-code-ide-extras-tests--clear-processes)
  (unwind-protect
      (let* ((other-dir "/test/other/")
             (other-buf (get-buffer-create "*claude-code[other]*"))
             (mock-process (start-process "mock-other" nil "sleep" "60"))
             (close-visible-called nil)
             (displayed-buffer nil))
        (puthash other-dir mock-process claude-code-ide--processes)
        (cl-letf (((symbol-function 'claude-code-ide--get-working-directory)
                   (lambda () "/test/new-project/"))
                  ((symbol-function 'claude-code-ide-extras--close-visible-sessions)
                   (lambda () (setq close-visible-called t)))
                  ((symbol-function 'claude-code-ide--display-buffer-in-side-window)
                   (lambda (buf) (setq displayed-buffer buf))))
          (claude-code-ide-extras--on-context-switch)
          (should close-visible-called)
          (should (null displayed-buffer)))
        (delete-process mock-process)
        (kill-buffer other-buf))
    (claude-code-ide-extras-tests--clear-processes)))

(ert-deftest claude-code-ide-extras-test-mode-installs-advice ()
  "Test that enabling the mode installs advice."
  (unwind-protect
      (progn
        (claude-code-ide-extras-project-switch-mode 1)
        (should (advice-member-p #'claude-code-ide-extras--on-context-switch 'project-switch-project)))
    (claude-code-ide-extras-project-switch-mode -1)))

(ert-deftest claude-code-ide-extras-test-mode-removes-advice ()
  "Test that disabling the mode removes advice."
  (claude-code-ide-extras-project-switch-mode 1)
  (claude-code-ide-extras-project-switch-mode -1)
  (should-not (advice-member-p #'claude-code-ide-extras--on-context-switch 'project-switch-project)))

(defun claude-code-ide-extras-run-tests ()
  "Run all claude-code-ide-extras tests."
  (interactive)
  (ert-run-tests-interactively "^claude-code-ide-extras-test-"))

(provide 'claude-code-ide-extras-tests)

;;; claude-code-ide-extras-tests.el ends here
