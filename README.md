# git-age.el

Highlight lines in Emacs buffers based on how recently they were modified in Git, and annotate how many lines came from the same commit.

## ✨ Features

* 🎨 Colors lines by **Git commit age**: newer = redder, older = greener.
* 🔢 Adds a suffix showing how many lines were introduced in the **same commit**.
* Non-intrusive: overlays are temporary and easy to clear.
* 🕵️ Great for reviewing:
  * Recently modified code
  * Stale sections untouched for years
  * Commits with broad footprint in a file

## 🔍 Why This Tool Helps

* 🕒 Surfaces recent changes – focus reviews on what's new.
* 📦 Reveals bulk changes – blocks of lines from the same commit.
* 🧩 Enhances merge conflict awareness – shows freshness of edits.
* 🧭 Aids team collaboration – clarifies who last worked on specific chunks.

## 📦 Installation

### Using `use-package` (recommended)

```elisp
(use-package git-age
  ;; :load-path "/path/to/git-age.el"
  :straight (git-age :type git :host github :repo "vaishnavkatiyar/git-age.el")
  :commands (git-age-visualize-buffer git-age-clear-overlays))
```

### Manual

Download `git-age.el` into your load path and add:

```elisp
(load "/path/to/git-age.el")
```

## 🧠 Usage

From any Git-tracked buffer:

### 🔍 Visualize Git age and commit footprint

```elisp
M-x git-age-visualize-buffer
```

* Applies a color gradient: **newer changes are red**, **older changes are green**.
* Adds suffix like: `➶ 5x` indicating 5 lines came from the same commit.

### ❌ Clear all overlays

```elisp
M-x git-age-clear-overlays
```

## 📁 How It Works

* Runs `git blame --line-porcelain` to gather:
  * Commit hash
  * Author timestamp
* Computes an **age score** from 0.0 (oldest) to 1.0 (newest).
* Groups and counts lines per commit.
* Displays overlays with:
  * Heatmap color background
  * Suffix annotation: `➶ <count>x`

## ✅ Requirements

* Emacs 25.1+
* Git must be installed and buffer must belong to a Git repo.
