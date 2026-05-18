---
name: feature-rollback
description: Annule les modifications du dernier /feature au niveau des contextes (technique et métier) et du journal de feedback. Restaure project-context.md depuis le dernier backup créé par context-keeper et business-context.md depuis le dernier backup créé par business-keeper, puis archive le dernier journal de feedback. Ne touche jamais aux commits git des trois repos (à gérer à la main via `git reset` si nécessaire). À utiliser quand on s'aperçoit après coup que la feature s'est mal passée et qu'il faut effacer ses traces dans le système.
---

# Skill `/feature-rollback` — annuler les traces de la dernière feature

Le développeur a invoqué `/feature-rollback`. Tu restaures les contextes (technique et métier) depuis leurs derniers backups et tu archives le dernier journal de feedback. Tu **ne touches jamais** aux commits des trois repos.

## Pré-vol

1. **Identifie le project root** : `pwd` doit être à la racine d'un projet qui a un `CLAUDE.md` (symlink) à sa racine.
2. **Vérifie les pré-requis** :
   ```bash
   ls .claude/.context-backup/ 2>/dev/null
   ls .claude/.business-backup/ 2>/dev/null
   ls .claude/feedback/ 2>/dev/null
   ```
   - Si tous les emplacements sont absents ou vides → annonce : « Aucun backup ni journal trouvé. Rien à rollback. »
   - Si certains seulement sont absents, continue avec ce qui existe.

## Étape 1 — Identifier les éléments à rollback

```bash
# Backup contexte technique le plus récent
ls -t .claude/.context-backup/*.md 2>/dev/null | head -1

# Backup contexte métier le plus récent
ls -t .claude/.business-backup/*.md 2>/dev/null | head -1

# Journal de feedback le plus récent (hors archivés et rolled-back)
ls -t .claude/feedback/*.md 2>/dev/null | grep -vE "\.(archived|rolled-back)\.md$" | head -1
```

Présente au dev ce qui sera fait :

```
🔁 Rollback de la dernière feature

À restaurer :
  - Contexte technique :
      depuis : .claude/.context-backup/<date>-<slug>-before.md
      vers   : .claude/project-context.md
  - Contexte métier :
      depuis : .claude/.business-backup/<date>-<slug>-before.md
      vers   : .claude/business-context.md
  - Journal feedback :
      archivage : .claude/feedback/<date>-<slug>.md → .claude/feedback/<date>-<slug>.rolled-back.md

Ce qui ne sera PAS touché :
  - Commits dans <api-dir>, <ios-dir>, <android-dir> (à gérer à la main via git si besoin)
  - Backups antérieurs (gardés dans .claude/.context-backup/ et .claude/.business-backup/)
  - Journaux antérieurs (gardés intacts)

Confirme :
  - « ok » pour tout rollback
  - « contexte technique seul » pour ne restaurer que project-context.md
  - « contexte métier seul » pour ne restaurer que business-context.md
  - « contextes seuls » pour restaurer les deux contextes sans toucher au journal
  - « journal seul » pour ne déplacer que le journal sans toucher aux contextes
  - « stop » pour annuler
```

## Étape 2 — Application selon la réponse

### Restauration du contexte technique (si « ok », « contexte technique seul » ou « contextes seuls »)

```bash
cp .claude/.context-backup/<backup-technique>.md .claude/project-context.md
```

Confirme : « ✅ `project-context.md` restauré depuis `<backup-technique>`. »

### Restauration du contexte métier (si « ok », « contexte métier seul » ou « contextes seuls »)

```bash
cp .claude/.business-backup/<backup-metier>.md .claude/business-context.md
```

Confirme : « ✅ `business-context.md` restauré depuis `<backup-metier>`. »

### Archivage du journal (si « ok » ou « journal seul »)

```bash
mv .claude/feedback/<journal>.md .claude/feedback/<journal>.rolled-back.md
```

Confirme : « ✅ Journal `<journal>.md` archivé en `<journal>.rolled-back.md` (gardé pour traçabilité, ignoré par `/feature-retro`). »

### Si « stop »

Annonce « Rollback annulé, rien n'a changé. » et termine.

## Étape 3 — Rappel sur les commits git

Termine systématiquement par ce rappel :

```
⚠️ Les commits git n'ont PAS été touchés. Si tu veux aussi annuler le code :
  - cd <api-dir>     && git log --oneline -5   (vérifier le dernier commit)
  - cd <api-dir>     && git reset --hard HEAD~1  (annuler le dernier commit, ATTENTION destructif)
  Idem pour <ios-dir> et <android-dir> si concernés.

C'est à toi de juger si tu veux annuler les commits — je ne le fais jamais automatiquement
(trop de risque d'effacer du travail légitime).
```

## Cas particuliers

### Backup technique présent mais pas business (ou inversement)

Cas courant : la feature n'a généré que des patches dans l'un des deux contextes. Tu restaures uniquement celui qui a un backup, et tu annonces clairement que l'autre n'a pas eu besoin d'être restauré.

### Plusieurs backups dans .context-backup/ ou .business-backup/

Le rollback prend par défaut **les plus récents** dans chaque dossier. Si le dev veut rollback un backup antérieur :

```
Si tu veux rollback un backup plus ancien :
  ls -lt .claude/.context-backup/
  ls -lt .claude/.business-backup/
  cp .claude/.context-backup/<choisi>.md .claude/project-context.md
  cp .claude/.business-backup/<choisi>.md .claude/business-context.md
```

Documente la commande, ne la fais pas à sa place sauf demande explicite.

### Tout est manquant

Annonce : « Aucun backup ni journal trouvé. Probablement rien à rollback. »

## Règles d'orchestration

- **Pas de `git reset` automatique sur les 3 repos.** Trop destructif pour être délégué.
- **Toujours afficher un récap avant d'agir** + demander une confirmation explicite.
- **Préserve les backups et journaux antérieurs** : ne supprime jamais les backups utilisés pour le rollback.
- **Suffixe `.rolled-back.md`** pour les journaux annulés (différent de `.archived.md` qui est utilisé par `/feature-retro`).

## Erreurs courantes à éviter

- Faire un `rm` sur les backups après usage (perte de la possibilité de re-rollback)
- Faire un `git reset` automatique
- Rollback sans confirmation
- Toucher à des journaux ou backups autres que les plus récents
- Lancer un rollback si rien n'a été produit (annoncer clairement et s'arrêter)
- Oublier l'un des deux contextes (technique ou métier) — toujours vérifier les deux dossiers de backup
