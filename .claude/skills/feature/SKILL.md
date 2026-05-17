---
name: feature
description: Implémente une feature dans un projet mobile natif + API Node/TS, de bout en bout. Orchestre la discovery (si nécessaire), le planning, la construction (API et/ou mobile selon scope), la review, et la capture obligatoire du feedback. Une seule gate humaine après le plan. Scopes supportés : api, mobile, api+mobile. Le workflow mobile est séquentiel (iOS → Android) pour garantir la parité.
---

# Skill `/feature` — orchestrateur de feature

Le développeur a invoqué `/feature <description>`. Tu orchestres l'ensemble du workflow avec **une gate humaine après le plan**, en t'adaptant au projet courant via `project-context.md`.

## Pré-vol obligatoire

Avant de lancer le moindre sub-agent :

1. **Identifie le project root** : `pwd` doit être à la racine d'un projet qui a un `CLAUDE.md` (symlink vers générique) à sa racine.
2. **Vérifie le bootstrap minimal** :
   - `CLAUDE.md` présent à la racine
   - `.claude/agents/feature-planner.md` accessible (symlink)
   - `.claude/agents/api-builder.md` accessible
   - `.claude/agents/api-reviewer.md` accessible
   - `.claude/agents/ios-builder.md` accessible
   - `.claude/agents/ios-reviewer.md` accessible
   - `.claude/agents/android-builder.md` accessible
   - `.claude/agents/android-reviewer.md` accessible
   - `.claude/agents/parity-auditor.md` accessible
   - `.claude/agents/ds-guardian.md` accessible
   - `.claude/agents/context-keeper.md` accessible
   - `.claude/agents/project-discoverer.md` accessible
   - `.claude/agents/system-retrospective.md` accessible
   Si un fichier manque, arrête-toi et signale : « Le système d'agents n'est pas correctement installé. Lance `~/work/claude-mobile-agents/install.sh` depuis la racine du projet. »
3. **Vérifie l'existence de `.claude/project-context.md`** :
   - Si **absent ou vide** → annonce « Premier `/feature` sur ce projet, je lance la discovery. » puis va à l'étape `Discovery` ci-dessous.
   - Si **présent** → lis-le et tiens-le pour vrai.
4. **Pré-vol git par sous-projet** : pour chaque repo détecté (`<api-dir>`, `<ios-dir>`, `<android-dir>`), exécute :
   ```bash
   git -C <dir> status --porcelain
   ```
   Si non vide, **avertis** le dev (sans bloquer) : « Attention, des modifications non commitées existent déjà dans `<dir>` (`<n>` fichiers). Le diff de cette feature sera imprécis dans le journal. Tu peux stash/commit avant ou laisser couler. ». Continue dans tous les cas.

## Discovery (uniquement au premier `/feature` du projet)

Si `project-context.md` est absent ou vide :

1. Lance l'agent `project-discoverer` avec :
   - **Contexte** : « Scanne ce projet pour en extraire la stack et les conventions. Génère `.claude/project-context.md` à partir du template. Si tu n'es pas sûr d'un champ, marque-le `<À CONFIRMER>`. Affiche un résumé à la fin, pas le fichier complet. »
2. Quand l'agent rend la main, présente son résumé au dev.
3. Demande explicitement : « Le contexte projet est-il bon ? Réponds :
   - **« ok »** pour valider et continuer avec la feature `<description>`
   - **« corrige : ... »** pour me dire ce qu'il faut ajuster (je relance la discovery)
   - **« je corrige à la main »** : j'attends que tu édites `.claude/project-context.md`, puis tape « ok » »
4. Une fois validé, **continue avec la feature**. Ne reposes pas la description, tu l'as déjà.

## Étape 1 — Planification

Lance l'agent `feature-planner` avec :

- **Description de la feature** : la phrase fournie par l'utilisateur, telle quelle
- **Contexte** : « Lis `CLAUDE.md` et `.claude/project-context.md`. Produis un plan technique conforme aux conventions du projet courant. Identifie le scope (api / mobile / api+mobile). Read-only. »

Récupère le plan en sortie. Si le scope est `mobile` ou `api+mobile`, rappelle au dev : « Cette feature touche le mobile. Le workflow sera séquentiel : iOS d'abord (ios-builder + ios-reviewer), puis Android qui porte le code iOS (android-builder + android-reviewer), puis parity-auditor pour un audit complet du domaine. Compter ~5-10 min selon la complexité, incluant deux builds (xcodebuild + gradle). »

## Étape 2 — Gate humaine (OBLIGATOIRE)

Affiche le plan **tel quel** dans la conversation, puis :

> Le plan ci-dessus est-il validé ? Réponds :
> - **« go »** pour lancer l'implémentation
> - **« revoir : ... »** pour demander une révision du plan (je relance le planner avec ton feedback)
> - **« stop »** pour annuler (aucun journal écrit)

**N'avance pas à l'étape 3 sans un « go » explicite.**

## Étape 3 — Implémentation et review (aiguillage par scope)

Le workflow mobile est **séquentiel** : iOS d'abord, puis Android utilise le code iOS comme spec implicite pour garantir la parité. Les reviews suivent chaque builder, et `android-reviewer` lit aussi le code iOS pour auditer la parité.

### Scope = `api`

1. Lance `api-builder` avec :
   - **Plan complet** validé
   - **Contexte** : « Implémente strictement le plan dans `<api-dir>` selon `project-context.md`. Compile avec la commande build du projet avant de rendre la main. Rapporte les fichiers touchés via `git -C <api-dir> status --short` et `git -C <api-dir> diff --stat`. »

2. Une fois api-builder fini, lance `api-reviewer` avec :
   - **Plan validé** + **rapport api-builder** + **liste des fichiers touchés**
   - **Contexte** : « Relis le delta git via `git -C <api-dir> diff`. Vérifie conformité à `CLAUDE.md` et `project-context.md`. Read-only. »

### Scope = `mobile`

Séquence stricte : `ios-builder` → `ios-reviewer` → `android-builder` → `android-reviewer` → `parity-auditor`.

1. Lance `ios-builder` avec :
   - **Plan complet** validé
   - **Contexte** : « Implémente la partie iOS du plan dans `<ios-dir>` selon `project-context.md`. Build via xcodebuild avant de rendre. Liste les nouveaux composants DS à reproduire côté Android. »

2. Lance `ios-reviewer` avec :
   - **Plan validé** + **rapport ios-builder** + **diff git iOS**
   - **Contexte** : « Relis le delta git iOS. Vérifie conformité à CLAUDE.md et project-context.md. Liste précisément ce qu'android-builder devra reproduire (écrans, DS, méthodes VM, DTOs). Read-only. »

3. Lance `android-builder` avec :
   - **Plan complet** validé + **rapport ios-builder** + **rapport ios-reviewer** (en particulier la section « À reproduire côté Android »)
   - **Contexte** : « Implémente la partie Android du plan dans `<android-dir>` en parité stricte avec le code iOS qui vient d'être produit (lis le diff git iOS). Mêmes noms d'écrans, composants DS, méthodes VM. Build via gradle assembleDebug avant de rendre. »

4. Lance `android-reviewer` avec :
   - **Plan validé** + **rapport android-builder** + **diff git Android** + **diff git iOS** (pour audit parité)
   - **Contexte** : « Relis le delta git Android. Audite la parité stricte avec le code iOS (lis aussi <ios-dir>). Toute divergence non documentée est bloquante. Read-only. »

5. Lance `parity-auditor` avec :
   - **Plan validé** + **les 4 rapports précédents** + **domaines fonctionnels touchés** (déduits des chemins des fichiers modifiés)
   - **Contexte** : « Audite la parité iOS ↔ Android sur les domaines fonctionnels touchés par cette feature, indépendamment du diff git. Compare l'ensemble des écrans, composants DS, méthodes VM et DTOs présents dans les deux apps. Classe chaque divergence en nouvelle (introduite par cette feature, signal de trou dans la review) ou héritée (dette préexistante). Read-only. »

6. Lance `ds-guardian` en mode **scoped** avec :
   - **Diffs git iOS et Android** (fichiers touchés par cette feature)
   - **Contexte** : « Mode `scoped`. Audite uniquement les fichiers touchés par cette feature. Focus sur axes 1 (bypass du DS sur les écrans) et 3 (cohérence fine iOS↔Android sur les composants touchés). N'exécute PAS les axes 2 et 4 (réservés au mode full). Read-only. Objectif : empêcher cette feature d'introduire une nouvelle dette DS. »

### Scope = `api+mobile`

Séquence complète : api d'abord, mobile ensuite.

1. `api-builder` → `api-reviewer` (comme scope `api`)
2. `ios-builder` → `ios-reviewer` → `android-builder` → `android-reviewer` → `parity-auditor` → `ds-guardian (scoped)` (comme scope `mobile`)

Justification : les apps consomment l'API, donc l'API doit être prête (au moins en code) avant que le mobile soit écrit. iOS sert ensuite de spec pour Android. `parity-auditor` consolide la vue parité structurelle, `ds-guardian` vérifie le respect fin du design system.

## Étape 5 — Synthèse

Présente au dev en français concis :

1. **Résumé** : ce qui a été créé / modifié (3-5 puces, regroupé par sous-projet)
2. **Tests à passer** : commandes `curl` / actions UI fournies par les builders
3. **Verdict review** : PASS / PASS_WITH_MINOR_ISSUES / BLOCKED
4. **Audit DS** (si scope mobile / api+mobile) : verdict de ds-guardian scoped, bypass éventuels, divergences fines détectées
5. **Bloquants** s'il y en a — avec proposition de relance du builder pour corriger
6. **TODO restant** : si scope `api` mais que la review signale du portage iOS/Android nécessaire, lister précisément ce qu'il faudra ajouter
7. **Suggestion `/ds-audit`** : si ds-guardian scoped a détecté des bypass / divergences récurrents, suggère de lancer `/ds-audit` en standalone plus tard pour un audit complet

## Étape 6 — Proposition de commit

Pour chaque sous-projet touché, propose au dev de commiter :

> Veux-tu commiter maintenant ?
> - **`<api-dir>`** : `<n>` fichiers touchés, suggestion `feat(api): <slug>` — réponds « commit api » ou « skip api »
> - **`<ios-dir>`** : ... (si applicable)
> - **`<android-dir>`** : ... (si applicable)
> - Ou réponds « skip » pour passer tous les commits.

Si le dev répond `commit <repo>`, exécute :
```bash
git -C <dir> add -A
git -C <dir> commit -m "<type>(<scope>): <slug>"
```

**Ne commit jamais sans accord explicite.** Récupère le hash du commit créé pour l'inclure dans le journal de feedback.

## Étape 7 — Mise à jour du contexte projet (OBLIGATOIRE)

Cette étape lutte contre l'obsolescence du `project-context.md`. Sans elle, le contexte fige une photo qui se périme à mesure que le projet évolue.

1. Lance l'agent `context-keeper` avec :
   - **Contexte** : « Analyse les diffs des sous-projets touchés par cette feature et propose des mises à jour ciblées de `.claude/project-context.md` selon les critères conservateurs définis dans ton prompt. Read-only. »

2. **Reçois son rapport**. Trois cas :

   **a) Rien à intégrer** (cas fréquent et normal) : le rapport indique « Aucun patch nécessaire ». Annonce-le au dev et passe directement à l'étape 8.

   **b) 1 à 5 patches proposés** : présente le rapport complet (analyse + patches) au dev. Puis pour chaque patch dans l'ordre :

   > **Patch <N>** — [helper|ds-component|pattern|convention|dependency]
   > Justification : `<...>`
   >
   > ```diff
   > ...
   > ```
   >
   > Réponds :
   > - **« apply »** pour appliquer
   > - **« skip »** pour passer
   > - **« edit : ... »** pour ajuster avant d'appliquer
   > - **« stop »** pour interrompre la mise à jour du contexte

3. **Avant d'appliquer le premier patch validé**, crée un backup obligatoire :
   ```bash
   mkdir -p .claude/.context-backup
   cp .claude/project-context.md ".claude/.context-backup/$(date +%Y-%m-%d)-<slug>-before.md"
   ```
   Ce backup permet à `/feature-rollback` de restaurer le contexte si la feature est annulée plus tard.

4. **Applique les patches validés** via Edit ciblé sur `.claude/project-context.md`. Si le `old_string` du diff ne correspond pas exactement au fichier, signale-le et propose au dev de demander à `context-keeper` de regénérer ce patch précis.

5. **Confirme** : « Patch N appliqué » (ou « skippé »).

6. **Mets à jour le champ frontmatter** `Dernière mise à jour automatique` de `project-context.md` avec la date du jour.

7. Récap au dev :
   ```
   Contexte mis à jour : <n> patches appliqués sur <m> proposés.
   Backup : .claude/.context-backup/<date>-<slug>-before.md
   Pour annuler : /feature-rollback
   ```

## Étape 8 — Capture du feedback (OBLIGATOIRE)

**Ne saute jamais cette étape**, même si le dev est pressé. Sans feedback, `/feature-retro` n'a rien à exploiter.

Affiche le formulaire suivant et **attends** la réponse :

```
Avant de clôturer, j'ai besoin de ton feedback (utile pour /feature-retro).

📊 Notes (1=mauvais, 5=excellent) :
- Qualité du plan          : ?/5
- Conformité du code livré : ?/5
- Pertinence de la review  : ?/5
- Effort manuel post-livraison (1=énorme, 5=rien à toucher) : ?/5
- Gain de temps ressenti   : ?/5

✍️ Texte libre :
- Qu'as-tu dû corriger à la main (le cas échéant) ?
- Qu'est-ce qu'on aurait dû détecter / mieux faire plus tôt ?

Tu peux répondre en une ligne par item. Pour skipper le texte libre, écris « ras ».
```

Une fois la réponse reçue, écris le journal dans `.claude/feedback/YYYY-MM-DD-<slug>.md` (slug en kebab-case) au format strict défini dans `CLAUDE.md` (frontmatter complet + sections).

Confirme : « Journal écrit dans `.claude/feedback/<filename>` — `/feature-retro` pourra l'exploiter. »

## Étape 9 — Clôture

Termine en demandant :

> Tu veux que je corrige les bloquants éventuels ? Tu veux que je commence le port iOS/Android (si la feature était scope api) ?

Si `.claude/feedback/` contient **5+ entrées non archivées**, ajoute :
> 💡 Tu as `<n>` journaux accumulés — bon moment pour lancer `/feature-retro` dès que tu auras 10 minutes.

Si la feature s'est mal passée et que tu veux tout annuler :
> Tu peux lancer `/feature-rollback` pour restaurer le `project-context.md` et archiver le journal de feedback de cette feature. Les commits des 3 repos ne seront pas touchés (à faire à la main via `git reset` si nécessaire).

## Règles d'orchestration

- **Gates humaines** : (1) après le plan, (2) à chaque patch context-keeper. Pas d'autre gate pendant build/review.
- **Pré-vol git non bloquant** : avertis et continue.
- **Discovery déclenchée automatiquement** si `project-context.md` absent ou incomplet (placeholders restants).
- **Si un sub-agent échoue ou rend un output vide** : remonte au dev, ne tente pas de réparer toi-même.
- **Si le build TS échoue dans api-builder** : api-builder doit corriger avant de rendre. Si persiste, remonte au dev.
- **Tu n'écris dans le projet** que (a) le journal de feedback en étape 8 et (b) les patches context-keeper validés en étape 7 (avec backup obligatoire avant la première application) — sinon délègue aux builders.
- **Tu ne commits jamais** sans accord explicite à l'étape 6.
- **Backup obligatoire** avant la première application d'un patch context-keeper, dans `.claude/.context-backup/`.

## Erreurs courantes à éviter

- Lancer api-builder sans « go » explicite du dev
- Sauter la discovery quand `project-context.md` est absent
- Laisser le dev deviner ce que fait chaque étape — annonce chaque transition (« Discovery en cours… », « Plan reçu, je te le présente… », « Lancement du builder… »)
- Sauter la review parce que le build a passé — la review attrape les écarts de convention
- Modifier `CLAUDE.md` ou les fichiers d'agents pendant l'exécution
- Skipper la capture de feedback (étape 7)
- Commiter automatiquement
- Mélanger les scopes (si scope `api` et le dev dit « ajoute aussi l'écran iOS », bascule en `api+mobile` proprement, ne fais pas du mobile en douce)
