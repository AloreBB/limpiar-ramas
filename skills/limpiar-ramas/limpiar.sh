#!/usr/bin/env bash
# Clean up git work that is already in main: worktrees, local branches, remote branches.
#
# Usage: limpiar.sh [--dry-run] [--all] [repo ...]
#   No repos given: current repo if inside one, else every repo under ~/proyectos.
#   --all: every repo under ~/proyectos.
#
# A branch counts as "in main" when its tip is an ancestor of origin/main, or when
# GitHub has a PR from it merged into main whose head is exactly that tip (squash merges).
# Never touched: main/master/staging/develop/dev, checked-out branch of the main checkout,
# worktrees with uncommitted changes, worktrees some process is sitting in.

set -uo pipefail

DRY=0
REPOS=()
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY=1 ;;
    --all) for d in "$HOME"/proyectos/*/; do [ -e "$d/.git" ] && REPOS+=("${d%/}"); done ;;
    *) REPOS+=("$a") ;;
  esac
done

PROTECTED_RE='^(main|master|staging|develop|dev|HEAD|release-please--.*)$'

if [ ${#REPOS[@]} -eq 0 ]; then
  if top=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    REPOS=("$(dirname "$top")")
  else
    for d in "$HOME"/proyectos/*/; do
      [ -e "$d/.git" ] && REPOS+=("${d%/}")
    done
  fi
fi

run() {
  if [ $DRY -eq 1 ]; then echo "    [dry-run] $*"; else "$@"; fi
}

# Is any live process using this directory (or below) as cwd? Then a session is working there.
dir_in_use() {
  local dir=$1 p cwd
  for p in /proc/[0-9]*; do
    cwd=$(readlink "$p/cwd" 2>/dev/null) || continue
    case "$cwd/" in "$dir"/*) return 0 ;; esac
  done
  return 1
}

clean_repo() {
  local repo=$1
  cd "$repo" || return
  echo "== $repo"

  if ! git remote get-url origin >/dev/null 2>&1; then echo "   sin remote origin, salto"; return; fi
  if ! git fetch -q --prune origin 2>/dev/null; then echo "   fetch falló, salto"; return; fi

  local main=""
  for m in main master; do
    git rev-parse -q --verify "refs/remotes/origin/$m" >/dev/null && { main=$m; break; }
  done
  [ -z "$main" ] && { echo "   sin origin/main ni origin/master, salto"; return; }

  local use_gh=0
  git remote get-url origin | grep -q github.com && command -v gh >/dev/null && use_gh=1

  # Branch -> sha of merged-into-main PR heads (one gh call per repo).
  declare -A PR_HEAD=()
  if [ $use_gh -eq 1 ]; then
    while IFS=$'\t' read -r br sha; do
      [ -n "$br" ] && PR_HEAD[$br]+=" $sha"
    done < <(gh pr list --state merged --base "$main" --limit 300 \
               --json headRefName,headRefOid -q '.[] | [.headRefName, .headRefOid] | @tsv' 2>/dev/null)
  fi

  # Commits on the first-parent line of main/staging. A branch whose tip is one of these was just
  # forked and has no work of its own yet (a fresh worktree), so it is never treated as merged.
  declare -A MAINLINE=()
  local lines=("origin/$main")
  git rev-parse -q --verify refs/remotes/origin/staging >/dev/null && lines+=(origin/staging)
  while read -r c; do MAINLINE[$c]=1; done < <(git rev-list --first-parent "${lines[@]}")

  in_main() { # $1 = sha, $2 = branch name
    case "${PR_HEAD[$2]:-}" in *"$1"*) return 0 ;; esac
    [ -n "${MAINLINE[$1]:-}" ] && return 1
    git merge-base --is-ancestor "$1" "origin/$main" 2>/dev/null
  }

  local main_wt main_head
  main_wt=$(git worktree list --porcelain | awk 'NR==1{print $2}')
  main_head=$(git -C "$main_wt" symbolic-ref -q --short HEAD)

  # 1. Worktrees
  local wt br sha
  while read -r wt br; do
    [ "$wt" = "$main_wt" ] && continue
    if [ ! -d "$wt" ]; then continue; fi  # prunable, handled below
    if [ -z "$br" ]; then echo "   SKIP worktree $wt: detached HEAD"; continue; fi
    [[ $br =~ $PROTECTED_RE ]] && { echo "   SKIP worktree $wt: rama protegida $br"; continue; }
    sha=$(git -C "$wt" rev-parse HEAD)
    if ! in_main "$sha" "$br"; then echo "   keep worktree $wt ($br): trabajo no está en $main"; continue; fi
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
      echo "   SKIP worktree $wt ($br): cambios sin commitear"; continue
    fi
    if dir_in_use "$wt"; then echo "   SKIP worktree $wt ($br): hay un proceso/sesión usándolo"; continue; fi
    echo "   - worktree $wt ($br)"
    run git worktree remove "$wt"
  done < <(git worktree list --porcelain | awk '
    /^worktree /{w=substr($0,10); b=""}
    /^branch /{b=$2; sub("refs/heads/","",b)}
    /^$/{print w, b; w=""}
    END{if(w!="") print w, b}')
  run git worktree prune

  # Branches still checked out in a remaining worktree can't be deleted.
  declare -A CHECKED_OUT=()
  while read -r b; do CHECKED_OUT[$b]=1; done < <(git worktree list --porcelain | awk '/^branch /{sub("refs/heads/","",$2); print $2}')

  # 2. Local branches
  while read -r br sha; do
    [[ $br =~ $PROTECTED_RE ]] && continue
    [ "$br" = "$main_head" ] && continue
    [ -n "${CHECKED_OUT[$br]:-}" ] && { echo "   SKIP rama local $br: está en checkout (worktree o repo principal)"; continue; }
    in_main "$sha" "$br" || continue
    echo "   - rama local $br"
    run git branch -D "$br"
  done < <(git for-each-ref --format='%(refname:short) %(objectname)' refs/heads)

  # 3. Remote branches
  while read -r ref sha; do
    br=${ref#origin/}
    [ "$br" = "origin" ] && continue
    [[ $br =~ $PROTECTED_RE ]] && continue
    [ -n "${CHECKED_OUT[$br]:-}" ] && { echo "   SKIP rama remota $br: está en checkout (worktree o repo principal)"; continue; }
    in_main "$sha" "$br" || continue
    echo "   - rama remota origin/$br"
    run git push -q origin --delete "$br"
  done < <(git for-each-ref --format='%(refname:short) %(objectname)' refs/remotes/origin)
}

for r in "${REPOS[@]}"; do
  ( clean_repo "$r" )
done
