# limpiar ramas

[![skills.sh](https://skills.sh/b/AloreBB/limpiar-ramas)](https://skills.sh/AloreBB/limpiar-ramas)

Borra lo que ya está en `main`: worktrees, ramas locales y ramas remotas cuyo trabajo ya fue
integrado. Nunca toca `staging`, `main`, ni trabajo sin mergear.

## Instalación

Con [skills.sh](https://skills.sh) (funciona en Claude Code, Cursor, Codex, Copilot y más):

```bash
npx skills add AloreBB/limpiar-ramas --skill limpiar-ramas
```

O todas las skills del repo, a todos tus agentes:

```bash
npx skills add AloreBB/limpiar-ramas --all
```

**En Claude Code como plugin:**

```
/plugin marketplace add AloreBB/limpiar-ramas
/plugin install limpiar-ramas@limpiar-ramas
```

**Manual:** copia `skills/limpiar-ramas/` a `~/.claude/skills/limpiar-ramas/`.

## Uso

Solo dilo y la skill se activa sola:

```
limpiar
limpiar ramas
/limpiar
limpia las ramas mergeadas
qué borrarías  (dry-run, no borra nada)
limpiar todo   (todos los repos de ~/proyectos)
```

## Qué cuenta como "en main"

- La punta de la rama es ancestro de `origin/main` (o `origin/master`) **y** entró por merge
  (no es un commit de la línea principal: una rama recién creada sin trabajo propio no cuenta), o
- GitHub tiene un PR mergeado a main desde esa rama con exactamente esa punta (squash merges).

## Nunca toca

- `main`, `master`, `staging`, `develop`, `dev`, `release-please--*` (local ni remota).
- La rama del checkout principal del repo.
- Worktrees con cambios sin commitear, con trabajo fuera de main, o con algún proceso usándolos
  (otra sesión trabajando ahí).

## Estructura

- `skills/limpiar-ramas/SKILL.md` — la skill.
- `skills/limpiar-ramas/limpiar.sh` — el script (`--all`, `--dry-run`, o rutas de repos explícitas).
- `.claude-plugin/marketplace.json` — marketplace para `/plugin install` en Claude Code.
