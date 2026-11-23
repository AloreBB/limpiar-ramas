---
name: limpiar-ramas
description: "Use when the user says 'limpiar', '/limpiar', 'limpiar ramas', 'limpia ramas', 'limpia worktrees' or asks to clean up git work that is already merged into main. Deletes worktrees, local branches and remote branches whose work is already in main. Never touches staging or unmerged work."
summary: Delete git work already merged into main - worktrees, local and remote branches - without touching staging or unmerged work.
version: 1.0.0
author: AloreBB
license: MIT
tags:
  - git
  - branches
  - worktrees
  - cleanup
  - claude-code
  - developer-tools
keywords:
  - limpiar
  - limpiar ramas
  - delete merged branches
  - git worktree remove
  - clean up branches
use_cases:
  - Delete worktrees whose branch is already merged into main
  - Delete local branches whose work is already in main
  - Delete remote branches whose work is already in main
  - Preview what would be deleted with --dry-run
---

# limpiar ramas — borra lo que ya está en main

Invocar la skill ES la autorización para borrar: no pidas confirmación. El script solo borra
trabajo que ya está en main, así que todo lo borrado es recuperable desde main.

## Alcance

- Dentro de un repo (o worktree) → solo ese repo.
- Fuera de un repo, o el usuario dice "todo" / "todos" / "server" → todos los repos de `~/proyectos` (`--all`).
- El usuario pide "ver" / "qué borrarías" / "prueba" → agrega `--dry-run` y no borres.

## Ejecutar

Corre `limpiar.sh` desde el directorio de esta skill, con el cwd en el repo objetivo:

```bash
<skill-dir>/limpiar.sh [--all] [--dry-run]
```

Puedes pasar rutas de repos explícitas como argumentos. Con `--all` puede tardar varios minutos
(fetch + gh por repo): timeout 600000.

## Qué cuenta como "en main"

- La punta de la rama es ancestro de `origin/main` (o `origin/master`) **y** entró por merge, no es un
  commit de la línea principal de main/staging (eso sería una rama recién creada sin trabajo propio), o
- GitHub tiene un PR mergeado a main desde esa rama con exactamente esa punta (squash merges).

## Nunca toca

- `main`, `master`, `staging`, `develop`, `dev`, `release-please--*` (local ni remota).
- La rama que tiene el checkout principal del repo.
- Worktrees con cambios sin commitear, con trabajo que no está en main, o con algún proceso
  usándolos (otra sesión de Claude/opencode trabajando ahí).

## Reporte

Resume por repo lo borrado (worktrees, ramas locales, ramas remotas) y lista los `SKIP` / `keep`
con su razón, para que el usuario decida sobre esos. Si algún comando falló, dilo con el error.
No intentes borrar a mano lo que el script saltó.
