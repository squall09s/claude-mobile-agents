---
name: feature-retro
description: Lance une rétrospective sur les journaux .claude/feedback/ du projet courant et applique les patches validés par le dev. Améliore project-context.md (toujours OK) ou les fichiers génériques (CLAUDE.md/agents/skill — nécessite confirmation supplémentaire car affecte tous les projets consommateurs). Patches validés un par un.
---

# Skill `/feature-retro` — rétrospective et amélioration

Le dev a lancé `/feature-retro`. Tu orchestres `system-retrospective`, présentes ses patches, en applique les validés. Tu distingues les patches **projet** (locaux) des patches **système** (génériques, partagés).

## Pré-vol

1. **pwd** = racine du projet (présence de `CLAUDE.md` + `.claude/`)
2. Compte les journaux non archivés :
   ```bash
   ls .claude/feedback/*.md 2>/dev/null | grep -v archived | wc -l
   ```
   - Si **< 3** → arrête-toi et dis : « Pas assez de matière pour une rétro utile (`<n>` journal(aux), minimum 3). Lance d'abord quelques `/feature`. »
   - Sinon → annonce : « `<n>` journaux exploitables, je lance la rétro. »

## Étape 1 — Analyse

Lance `system-retrospective` avec :

- **Contexte** : « Analyse les journaux non archivés dans `.claude/feedback/`. Produis jusqu'à 8 patches numérotés en diff. Classe chaque patch comme `projet` (modifie `.claude/project-context.md` du projet courant) ou `système` (modifie un fichier générique partagé). Read-only, propose seulement. »

Récupère le rapport complet.

## Étape 2 — Présentation au dev

Affiche **l'intégralité du rapport** (statistiques + patterns + patches). Puis :

> Je vais te présenter chaque patch un par un. Pour chaque, réponds :
> - **« apply »** pour l'appliquer
> - **« skip »** pour le passer
> - **« edit : ... »** pour ajuster avant d'appliquer
> - **« stop »** pour interrompre la rétro

## Étape 3 — Validation patch par patch

Pour chaque patch dans l'ordre :

1. **Affiche le patch seul** (numéro, gravité, scope projet/système, fichier, justification, diff)
2. **Si patch système** : ajoute un avertissement explicite avant de demander la validation :
   > ⚠️ **Ce patch est de scope `système`**. Si tu l'appliques, il sera versionné dans `~/work/claude-mobile-agents/` et affectera **tous les projets** qui consomment ce repo. Tu confirmes l'impact ? Réponds « apply » seulement si oui.
3. **Attends la réponse**
4. **Applique selon la réponse** :
   - `apply` → utilise Edit pour appliquer le diff au fichier cible.
     - Si patch **projet** : Edit sur `.claude/project-context.md` du projet courant.
     - Si patch **système** : Edit sur le fichier symlinké (qui pointe vers le repo générique). L'Edit modifiera le fichier source dans `~/work/claude-mobile-agents/`. **Vérifie après l'Edit** que le fichier source a bien changé : `git -C ~/work/claude-mobile-agents status --short`.
     - Si le `old_string` du diff ne correspond pas exactement au fichier, signale-le et propose au dev de demander à `system-retrospective` de regénérer ce patch.
   - `skip` → passe au suivant
   - `edit : ...` → relance `system-retrospective` avec UNIQUEMENT ce patch + le feedback (« revoir le patch N pour : ... »). Récupère la nouvelle version, l'affiche, redemande validation.
   - `stop` → arrête la boucle, passe à l'étape 5 sans appliquer les restants
5. **Confirme** : « Patch N appliqué à `<fichier>` (scope `projet|système`) » (ou « skippé »).

## Étape 4 — Commit des patches système

Si **au moins un patch `système` a été appliqué**, propose au dev :

> J'ai appliqué `<n>` patche(s) système (versionnés dans `~/work/claude-mobile-agents/`). Veux-tu que je commit dans ce repo ? Suggestion de message : `retro: <résumé court>` — réponds « commit système » ou « skip système ».

Si réponse positive :
```bash
git -C ~/work/claude-mobile-agents add -A
git -C ~/work/claude-mobile-agents commit -m "retro: <résumé>"
```

**Ne commit jamais le repo générique sans accord explicite.**

Les patches `projet` ne nécessitent pas de commit système — ils restent locaux. À toi de proposer au dev de commit `.claude/project-context.md` séparément s'il versionne ce fichier, mais ce n'est pas géré ici (probablement local-only).

## Étape 5 — Archivage des journaux

> J'ai appliqué `<n_applied>` patches sur `<n_proposed>` proposés. Tu veux archiver les journaux utilisés pour cette rétro ? (ils restent lisibles mais ne seront plus pris en compte par la prochaine rétro)
> - **« oui »** : je renomme chaque journal en `<nom>.archived.md`
> - **« non »** : je laisse en l'état
> - **« partiel »** : tu me donnes les slugs à archiver

Renomme via `mv .claude/feedback/<nom>.md .claude/feedback/<nom>.archived.md`.

## Étape 6 — Synthèse

```
Rétro terminée.
- Patches appliqués : <n> (sur <m> proposés)
  - projet : <n>
  - système : <n>
- Patches skippés : <n>
- Fichiers modifiés (projet) : <liste>
- Fichiers modifiés (système, dans ~/work/claude-mobile-agents/) : <liste>
- Journaux archivés : <n>
- Prochaine action conseillée : <ex. relancer /feature pour valider que les nouveaux prompts fonctionnent>
```

## Règles d'orchestration

- **Tu n'appliques jamais un patch sans `apply` explicite** du dev
- **Tu n'appliques jamais un patch système sans confirmation supplémentaire**
- **Tu ne crées pas de nouveaux patches** toi-même — seul `system-retrospective` les propose
- **Périmètre verrouillé** : projet = `.claude/project-context.md` uniquement ; système = `CLAUDE.md` + `.claude/agents/*.md` + `.claude/skills/*/SKILL.md` (via symlinks)
- **Tu ne commits jamais sans accord explicite** (ni le projet, ni le repo générique)
- **Si Edit échoue** (`old_string` ne matche pas), signale-le et propose au dev de demander à `system-retrospective` de regénérer ce patch précis

## Erreurs courantes à éviter

- Appliquer tous les patches d'un coup
- Skipper l'affichage du rapport complet avant les patches
- Toucher à d'autres fichiers que ceux du périmètre
- Réécrire les prompts toi-même au lieu d'appliquer les diffs
- Archiver les journaux sans demander
- Commit auto du repo générique (impact tous les autres projets, demande validation !)
