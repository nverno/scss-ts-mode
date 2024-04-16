;;; scss-ts-mode.el --- Tree-sitter support for Scss -*- lexical-binding: t; -*-

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/scss-ts-mode
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1"))
;; Created: 16 April 2024
;; Keywords: languages, tree-sitter, css, scss

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;; Code:

(require 'treesit)
(require 'css-mode)


(defcustom scss-indent-offset 4
  "Number of spaces for each indentation step."
  :group 'scss
  :type 'integer
  :safe 'integerp)


;;; Indentation

(defvar scss-ts-mode--indent-rules
  `((scss ,@(assoc-default 'css css--treesit-indent-rules)))
  "Tree-sitter indentation rules for `scss-ts-mode'.")


;;; Font-locking

(defvar scss-ts-mode--keywords
  '("and" "or" "not" "only" "selector"
    "@mixin" "@function" "@keyframes" "@return" "@if" "@else"
    "@while" "@each" "@for" "from" "through" "in"))

(defvar scss-ts-mode--builtins
  '("@debug" "@error" "@warn"))

(defvar scss-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :feature 'comment
   :language 'scss
   '([(single_line_comment) (comment)] @font-lock-comment-face)

   :feature 'string
   :language 'scss
   '([(plain_value) (string_value)] @font-lock-string-face)

   :feature 'keyword
   :language 'scss
   `([,@scss-ts-mode--builtins] @font-lock-builtin-face

     [,@scss-ts-mode--keywords (to) (at_keyword)] @font-lock-keyword-face

     ["@include" "@import" "@use" "@namespace" "@charset"
      "@forward" "@at-root" "@media" "@apply" "@extend" "@supports"]
     @font-lock-preprocessor-face)

   :feature 'definition
   :language 'scss
   '((function_statement
      (name) @font-lock-function-name-face
      (parameters
       (parameter) @font-lock-variable-name-face) :?)

     (mixin_statement
      (name) @font-lock-function-name-face
      (parameters
       (parameter) @font-lock-variable-name-face) :?)
     
     (keyframes_name) @font-lock-function-name-face

     (placeholder (name) @font-lock-function-name-face)

     (declaration
      (variable_name) @font-lock-variable-name-face)

     (argument
      (argument_name) @font-lock-variable-name-face)

     (parameter
      (variable_name) @font-lock-variable-name-face)
     
     (namespace_statement
      (namespace_name) @font-lock-type-face)

     (for_statement
      (variable) @font-lock-variable-name-face)

     (each_statement
      (key) @font-lock-variable-name-face))
   
   :feature 'variable
   :language 'scss
   '((variable_value) @font-lock-variable-use-face

     (each_statement
      (value) @font-lock-variable-name-face)
     ;; (each_statement
     ;;  (variable_value) @font-lock-variable-name-face)
     ;; (for_statement
     ;;  (_
     ;;   (variable_value) @font-lock-variable-name-face))
     )

   :language 'scss
   :feature 'operator
   `(["=" "~=" "^=" "|=" "*=" "$="
      "~" ">" "+" "-" "*" "/" ">=" "<=" "%"
      "::"
      (nesting_selector)]
     @font-lock-operator-face)

   :feature 'selector
   :language 'scss
   '((class_selector) @css-selector
     (child_selector) @css-selector
     (id_selector) @css-selector
     (tag_name) @css-selector
     (class_name) @css-selector)

   :feature 'property
   :language 'scss
   `([(attribute_name) (property_name) (feature_name)] @font-lock-property-name-face)

   :feature 'function
   :language 'scss
   '((call_expression (function_name) @font-lock-function-call-face)
     (important) @font-lock-preprocessor-face
     (include_statement
      (identifier) @font-lock-function-name-face))

   :feature 'constant
   :language 'scss
   '([(integer_value) (float_value)] @font-lock-number-face
     
     (unit) @font-lock-constant-face

     [(class_name)] @font-lock-type-face)

   :feature 'query
   :language 'scss
   '([(keyword_query)] @font-lock-property-use-face)

   :feature 'bracket
   :language 'scss
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :feature 'delimiter
   :language 'scss
   '(([":" ";"]) @font-lock-delimiter-face))
  "Tree-sitter font-lock settings for `scss-ts-mode'.")


(defvar scss-ts-mode--syntax-table
  (let ((tab (copy-syntax-table css-mode-syntax-table)))
    (modify-syntax-entry ?/ ". 124" tab)
    (modify-syntax-entry ?* ". 23b" tab)
    (modify-syntax-entry ?\n ">" tab)
    tab))

;;;###autoload
(define-derived-mode scss-ts-mode css-ts-mode "SCSS"
  :syntax scss-ts-mode--syntax-table
  (when (treesit-ready-p 'scss)
    ;; Borrowed from `css-mode'.
    (setq-local syntax-propertize-function
                css-syntax-propertize-function)
    (add-hook 'completion-at-point-functions
              #'css-completion-at-point nil 'local)
    (setq-local fill-paragraph-function #'css-fill-paragraph)
    (setq-local adaptive-fill-function #'css-adaptive-fill)
    ;; `css--fontify-region' first calls the default function, which
    ;; will call tree-sitter's function, then it fontifies colors.
    (setq-local font-lock-fontify-region-function #'css--fontify-region)

    ;; Tree-sitter specific setup.
    (treesit-parser-create 'scss)
    (setq-local treesit-simple-indent-rules scss-ts-mode--indent-rules)
    (setq-local treesit-defun-type-regexp "rule_set")
    (setq-local treesit-defun-name-function #'css--treesit-defun-name)
    (setq-local treesit-font-lock-settings scss-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment definition)
                  (keyword string)
                  (selector query property constant)
                  (variable function operator bracket delimiter)))
    (setq-local treesit-simple-imenu-settings
                `(( nil ,(rx bos (or "rule_set" "media_statement") eos)
                    nil nil)))

    (treesit-major-mode-setup)))

(derived-mode-add-parents 'scss-ts-mode '(css-ts-mode))

(when (treesit-ready-p 'scss)
  (add-to-list 'auto-mode-alist '("\\.scss\\'" . scss-ts-mode)))

(provide 'scss-ts-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; scss-ts-mode.el ends here
