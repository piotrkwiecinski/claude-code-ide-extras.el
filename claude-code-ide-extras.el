;;; claude-code-ide-extras.el --- Extra features for claude-code-ide  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Piotr Kwiecinski

;; Author: Piotr Kwiecinski
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (claude-code-ide "0.2.6"))
;; Keywords: ai, claude, code, assistant
;; URL: https://github.com/piotrkwiecinski/claude-code-ide-extras.el

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Extra features for claude-code-ide.el that extend the core package
;; with additional integrations.
;;
;; Currently provides:
;; - Automatic Claude Code window switching when changing projects
;;   via `project-switch-project'.
;;
;; Usage:
;;   (require 'claude-code-ide-extras)
;;   (claude-code-ide-extras-project-switch-mode 1)

;;; Code:

(require 'claude-code-ide)

(defgroup claude-code-ide-extras nil
  "Extra features for Claude Code IDE."
  :group 'claude-code-ide
  :prefix "claude-code-ide-extras-")

(defun claude-code-ide-extras--close-visible-sessions ()
  "Close all visible Claude Code side windows."
  (maphash (lambda (directory _)
             (let* ((buf-name (funcall claude-code-ide-buffer-name-function directory))
                    (buf (get-buffer buf-name)))
               (when-let ((win (and buf (get-buffer-window buf))))
                 (delete-window win))))
           claude-code-ide--processes))

(defun claude-code-ide-extras--on-context-switch (&rest _args)
  "Update Claude Code side window after switching projects.
If a Claude Code session exists for the current project, display it.
Otherwise, close any visible Claude Code side windows."
  (let* ((new-dir (claude-code-ide--get-working-directory))
         (new-buffer-name (funcall claude-code-ide-buffer-name-function new-dir))
         (new-buffer (get-buffer new-buffer-name))
         (new-process (claude-code-ide--get-process new-dir)))
    (claude-code-ide-extras--close-visible-sessions)
    (when (and new-buffer
               (buffer-live-p new-buffer)
               new-process
               (process-live-p new-process))
      (claude-code-ide--display-buffer-in-side-window new-buffer))))

;;;###autoload
(define-minor-mode claude-code-ide-extras-project-switch-mode
  "Toggle extra features for Claude Code IDE.
When enabled, automatically follows project switches to show the
appropriate Claude Code session."
  :global t
  :group 'claude-code-ide-extras
  (if claude-code-ide-extras-project-switch-mode
      (advice-add 'project-switch-project :after #'claude-code-ide-extras--on-context-switch)
    (advice-remove 'project-switch-project #'claude-code-ide-extras--on-context-switch)))

(provide 'claude-code-ide-extras)

;;; claude-code-ide-extras.el ends here
