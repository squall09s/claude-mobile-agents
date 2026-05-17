---
name: feature-rollback
description: Annule les modifications du dernier /feature au niveau du contexte projet et du journal de feedback. Restaure le project-context.md depuis le dernier backup créé par context-keeper et archive le dernier journal de feedback. Ne touche jamais aux commits git des trois repos (à gérer à la main via `git reset` si nécessaire). À utiliser quand on s'aperçoit après coup que la feature s'est mal passée et qu'il faut effacer ses traces dans le système.
---

# Skill `/feature-rollback` — annuler les traces de la dernière feature

Le développeur a invoqué `/feature-rollback`. Tu restaures le `project-context.md` depuis le dernier backup créé par `context-keeper` et tu archives le dernier journal de feedback. Tu **ne touches jamais** aux commits des trois repos.

## Pré-vol

1. **Identifie le project root** : `pwd` doit être à la racine d'un projet qui a un `CLAUDE.md` (symlink) à sa racine.
2. **Vérifie les pré-requis** :
   ```bash
   ls .claude/.context-backup/ 2>/dev/null
   ls .claude/feedback/ 2>/dev/null
   ```
   - Si `.claude/.context-backup/` est absent ou vide → annonce : « Aucun backup de contexte trouvé. Soit aucun `/feature` n'a tourné, soit context-keeper n'a jamais eu à appliquer de patch. Rien à rollback côté contexte. »
   - Si `.claude/feedback/` est vide ou ne contient que des `*.archived.md` / `*.rolled-back.md` → annonce : « Aucun journal de feedback récent. »
   - Si l'un des deux manque mais pas l'autre, continue quand même pour ce qui existe.

## Étape 1 — Identifier les éléments à rollback

```bash
# Backup le plus récent (par date de modif, fallback sur le tri du nom)
ls -t .claude/.context-backup/*.md 2>/dev/null | head -1

# Journal de feedback le plus récent (hors archivés et rolled-back)
ls -t .claude/feedback/*.md 2>/dev/null | grep -vE "\.(archived|rolled-back)\.md$" | head -1
```

Présente au dev ce qui sera fait :

```
🔁 Rollback de la dernière feature

À restaurer :
  - Contexte projet :
      depuis : .claude/.context-backup/<date>-<slug>-before.md
      vers   : .claude/project-context.md
  - Journal feedback :
      archivage : .claude/feedback/<date>-<slug>.md → .claude/feedback/<date>-<slug>.rolled-back.md

Ce qui ne sera PAS touché :
  - Commits dans <api-dir>, <ios-dir>, <android-dir> (à gérer à la main via git si besoin)
  - Backups antérieurs (gardés dans .claude/.context-backup/)
  - Journaux antérieurs (gardés intacts)

Confirme :
  - « ok » pour tout rollback
  - « contexte seul » pour ne restaurer que project-context.md (garder le journal)
  - « journal seul » pour ne déplacer que le journal (garder le contexte modifié)
  - « stop » pour annuler
```

## Étape 2 — Application selon la réponse

### Si « ok » ou « contexte seul »

```bash
cp .claude/.context-backup/<backup>.md .claude/project-context.md
```

Confirme : « ✅ `project-context.md` restauré depuis `<backup>`. »

### Si « ok » ou « journal seul »

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

### Plusieurs backups dans .context-backup/

Le rollback prend par défaut **le plus récent**. Si le dev veut rollback un backup antérieur :

```
Si tu veux rollback un backup plus ancien :
  ls -lt .claude/.context-backup/
  cp .claude/.context-backup/<choisi>.md .claude/project-context.md
```

Documente la commande, ne la fais pas à sa place sauf demande explicite.

### Backup manquant mais journal présent

Cas où context-keeper n'a rien appliqué (pas de patch) mais où un journal a été écrit.
Tu peux quand même archiver le journal seul. Annonce-le clairement.

### Journal manquant mais backup présent

Cas où l'utilisateur a déjà supprimé/archivé le journal à la main, ou où le `/feature` a été interrompu avant l'étape feedback. Tu peux restaurer le contexte seul.

## Règles d'orchestration

- **Pas de `git reset` automatique sur les 3 repos.** C'est trop destructif pour être délégué.
- **Toujours afficher un récap avant d'agir** + demander une confirmation explicite.
- **Préserve les backups et journaux antérieurs** : ne supprime jamais le backup utilisé pour le rollback (au cas où tu changerais d'avis).
- **Suffixe `.rolled-back.md`** pour les journaux annulés (différent de `.archived.md` qui est utilisé par `/feature-retro` après exploitation normale).

## Erreurs courantes à éviter

- Faire un `rm` sur le backup après usage (perte de la possibilité de re-rollback)
- Faire un `git reset` automatique
- Rollback sans confirmation
- Toucher à des journaux ou backups autres que les plus récents
- Lancer un rollback si rien n'a été produit (annoncer clairement et s'arrêter)
