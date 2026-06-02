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
   - `.claude/agents/i18n-collector.md` accessible
   - `.claude/agents/parity-auditor.md` accessible
   - `.claude/agents/ds-guardian.md` accessible
   - `.claude/agents/context-keeper.md` accessible
   - `.claude/agents/business-keeper.md` accessible
   - `.claude/agents/project-discoverer.md` accessible
   - `.claude/agents/system-retrospective.md` accessible
   Si un fichier manque, arrête-toi et signale : « Le système d'agents n'est pas correctement installé. Lance `~/work/claude-mobile-agents/install.sh` depuis la racine du projet. »
3. **Vérifie l'existence et l'état de `.claude/project-context.md` ET `.claude/business-context.md`** :
   - Si l'un des deux est **absent ou template-like** (placeholders `<À CONFIRMER>` ou `<...>` encore présents en majorité) → annonce « Premier `/feature` sur ce projet (ou contexte incomplet), je lance la discovery. » puis va à l'étape `Discovery` ci-dessous.
   - Si les deux sont **présents et remplis** → lis-les et tiens-les pour vrai.
4. **Pré-vol git par sous-projet** : pour chaque repo détecté (`<api-dir>`, `<ios-dir>`, `<android-dir>`), exécute :
   ```bash
   git -C <dir> status --porcelain
   ```
   Si non vide, **avertis** le dev (sans bloquer) : « Attention, des modifications non commitées existent déjà dans `<dir>` (`<n>` fichiers). Le diff de cette feature sera imprécis dans le journal. Tu peux stash/commit avant ou laisser couler. ». Continue dans tous les cas.
5. **Détecte le mode d'exécution recommandé** (cf. `CLAUDE.md`, section « Modes d'exécution d'une feature ») :
   - Si la description contient « refactor pur », « renommage », « aucun changement de comportement métier », « cosmétique », « cleanup », ou si elle évoque un bundle (« lance les features X, Y et Z », « enchaîne ces N petites tâches »), **propose explicitement le mode `light`** :
     > Cette feature ressemble à un cas typique du **mode `light`** (refactor pur / petite feature / bundle). Le pipeline complet (planner + reviewers + parity-auditor + ds-guardian) prend ~30-60 min et a montré son sur-coût sur ce type de tâche (gain_time 1-2/5 dans les rétros). Le mode `light` lance les builders en série, sans review formelle, et tient en ~5-15 min. Réponds :
     > - **« light »** pour le mode allégé
     > - **« full »** pour le pipeline complet (défaut)
   - Pour toute autre description, démarre directement en mode `full`.

## Mode `light` — pipeline allégé

Si le dev a validé le mode `light` au pré-vol :

1. **Pas de planner formel** : pose 2-4 questions structurantes au dev (décisions de schéma, choix de bornes / défauts), récupère les réponses, puis enchaîne directement les builders.
2. **Pipeline** : api-builder (si applicable) → ios-builder → android-builder, en série stricte. Chaque builder lit le diff du précédent comme spec implicite (déjà la pratique côté Android pour iOS, à étendre côté Android pour API).
3. **Pas de reviewers, pas de i18n-collector, pas de parity-auditor, pas de ds-guardian**. L'audit est reporté à `/feature-retro` ou à un `/ds-audit` standalone. Si la feature `light` a introduit des clés de traduction, c'est au dev de les ajouter manuellement dans son outil de gestion de traductions — sinon attendre la prochaine feature `full` pour que `i18n-collector` les collecte (à condition qu'elles soient toujours dans le diff git, donc avant commit).
4. **Context-keeper et business-keeper en batch** : au lieu d'une gate par patch, présente tous les patches en une fois et accepte une réponse groupée (« apply 1,3,5 » ou « apply all » / « skip all »).
5. **Journal de feedback unique** pour l'ensemble du run (même si plusieurs features bundlées), avec `review_verdict: NO_REVIEW_MODE_LIGHT`.

En cas de doute en cours d'exécution (ex. divergence iOS↔Android non triviale détectée par le builder Android), le builder peut suggérer au dev de basculer la feature en `full` pour cette étape uniquement. Le dev tranche.

## Discovery (uniquement au premier `/feature` du projet)

Si `project-context.md` ou `business-context.md` est absent ou template-like :

1. Lance l'agent `project-discoverer` avec :
   - **Contexte** : « Scanne ce projet pour en extraire (a) la stack et les conventions techniques (project-context.md) et (b) la vue produit : rôles, vocabulaire, entités/états, flows, carte des écrans (business-context.md). Génère les deux fichiers à partir des templates. Si tu n'es pas sûr d'un champ, marque-le `<À CONFIRMER>`. Affiche un résumé à la fin, pas les fichiers complets. »
2. Quand l'agent rend la main, présente son résumé au dev (technique + métier).
3. Demande explicitement : « Les deux contextes sont-ils bons ? Réponds :
   - **« ok »** pour valider et continuer avec la feature `<description>`
   - **« corrige : ... »** pour me dire ce qu'il faut ajuster (je relance la discovery)
   - **« je corrige à la main »** : j'attends que tu édites `.claude/project-context.md` ou `.claude/business-context.md`, puis tape « ok » »
4. Une fois validé, **continue avec la feature**. Ne reposes pas la description, tu l'as déjà.

## Étape 1 — Planification

Lance l'agent `feature-planner` avec :

- **Description de la feature** : la phrase fournie par l'utilisateur, telle quelle
- **Contexte** : « Lis `CLAUDE.md`, `.claude/project-context.md` (technique) ET `.claude/business-context.md` (métier). Produis un plan technique conforme aux conventions du projet courant, en utilisant le vocabulaire métier et en positionnant la feature dans les flows existants. Identifie le scope (api / mobile / api+mobile). Read-only. »

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

Séquence stricte : `ios-builder` → `ios-reviewer` → `android-builder` → `android-reviewer` → `i18n-collector` → `parity-auditor` → `ds-guardian (scoped)`.

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

5. Lance `i18n-collector` avec :
   - **Plan validé** + **slug de la feature** (pour le dossier de sortie) + **rapports ios-builder / android-builder** (pour connaître les fichiers touchés)
   - **Contexte** : « Scanne les diffs git iOS et Android pour extraire les nouvelles clés de traduction introduites par cette feature, selon les patterns d'invocation et la convention de clés déclarés dans la section `## i18n` de `project-context.md`. Génère un fichier `.strings` par langue active dans `<workspace>/.claude/i18n-pending/<date>-<slug>/`. Read-only sur les repos iOS / Android, écriture uniquement dans le dossier de sortie. Si la section `## i18n` indique `non implémentée — strings hardcodées`, rends EMPTY sans rien écrire. Signale les divergences iOS ↔ Android sur les clés pour que parity-auditor les inclue à son audit. »

6. Lance `parity-auditor` avec :
   - **Plan validé** + **les 5 rapports précédents** (incluant i18n-collector) + **domaines fonctionnels touchés** (déduits des chemins des fichiers modifiés)
   - **Contexte** : « Audite la parité iOS ↔ Android sur les domaines fonctionnels touchés par cette feature, indépendamment du diff git. Compare l'ensemble des écrans, composants DS, méthodes VM, DTOs **et clés i18n** présents dans les deux apps. Réutilise les divergences de clés signalées par i18n-collector pour la catégorie i18n de ton rapport. Classe chaque divergence en nouvelle (introduite par cette feature, signal de trou dans la review) ou héritée (dette préexistante). Read-only. »

7. Lance `ds-guardian` en mode **scoped** avec :
   - **Diffs git iOS et Android** (fichiers touchés par cette feature)
   - **Contexte** : « Mode `scoped`. Audite uniquement les fichiers touchés par cette feature. Focus sur axes 1 (bypass du DS sur les écrans) et 3 (cohérence fine iOS↔Android sur les composants touchés). N'exécute PAS les axes 2 et 4 (réservés au mode full). Read-only. Objectif : empêcher cette feature d'introduire une nouvelle dette DS. »

### Scope = `api+mobile`

Séquence complète : api d'abord, mobile ensuite.

1. `api-builder` → `api-reviewer` (comme scope `api`)
2. `ios-builder` → `ios-reviewer` → `android-builder` → `android-reviewer` → `i18n-collector` → `parity-auditor` → `ds-guardian (scoped)` (comme scope `mobile`)

Justification : les apps consomment l'API, donc l'API doit être prête (au moins en code) avant que le mobile soit écrit. iOS sert ensuite de spec pour Android. `i18n-collector` collecte les nouvelles clés de traduction introduites par les builders mobiles. `parity-auditor` consolide la vue parité structurelle (incluant les clés i18n), `ds-guardian` vérifie le respect fin du design system.

## Étape 4 — Gate visuelle (features design/maquette uniquement)

Déclenche cette étape **uniquement** si la description de la feature fournit une
référence visuelle (mots « maquette », « comme l'image », « fidèle au design »,
« comme sur les écrans du dossier », ou un fichier image/PDF cité). Sinon,
passe directement à l'étape 5.

1. **Avant la review** (ou juste après, selon l'outillage), capture les écrans
   cibles sur simulateur/émulateur. Si le projet documente un outillage de
   capture (MCP simulateur, script, seed de données) dans `project-context.md`,
   utilise-le ; sinon demande au dev s'il veut lancer la capture ou acter la
   limite « vérif lecture-code uniquement ».
2. **Compare chaque écran capturé à la maquette** sur : structure (sections,
   ordre, hiérarchie), états (plein / vide / variantes), pied d'écran (FAB /
   boutons flottants vs tabbar), ouverture d'au moins un détail depuis chaque
   écran refondu. Ces deux derniers points ne sont visibles QU'EN RUNTIME.
3. **Signale tout composant DS créé mais non câblé** dans l'écran cible : c'est
   le principal symptôme « code livré mais hors maquette ».
4. Si des écarts visuels bloquants sont détectés, relance le builder concerné
   sur les correctifs ciblés avant de poursuivre.
5. Si la vérif n'a pas pu être effectuée (pas d'outillage, données non seedées,
   API non déployée), **acte-le explicitement** dans la synthèse et dans le
   journal : « fidélité maquette non démontrée à l'écran, vérifiée en lecture
   de code uniquement ».

## Étape 5 — Synthèse

Présente au dev en français concis :

1. **Résumé** : ce qui a été créé / modifié (3-5 puces, regroupé par sous-projet)
2. **Tests à passer** : commandes `curl` / actions UI fournies par les builders
3. **Verdict review** : PASS / PASS_WITH_MINOR_ISSUES / BLOCKED
4. **Audit DS** (si scope mobile / api+mobile) : verdict de ds-guardian scoped, bypass éventuels, divergences fines détectées
4b. **Collecte i18n** (si scope mobile / api+mobile) : verdict d'`i18n-collector` (COLLECTED / EMPTY / INCOMPLETE), nombre de clés extraites, chemin du dossier de sortie. Si INCOMPLETE (clés en `TODO` côté langue principale), liste-les explicitement et rappelle au dev qu'il doit les peupler à la main avant d'importer dans son outil de traductions. Si EMPTY, mention en une ligne (ne pas alourdir la synthèse).
5. **Bloquants** s'il y en a — avec proposition de relance du builder pour corriger
6. **TODO restant** : si scope `api` mais que la review signale du portage iOS/Android nécessaire, lister précisément ce qu'il faudra ajouter
7. **Suggestion `/ds-audit`** : si ds-guardian scoped a détecté des bypass / divergences récurrents, suggère de lancer `/ds-audit` en standalone plus tard pour un audit complet
8. **Dette héritée détectée par parity-auditor** (si scope mobile/api+mobile) : si le verdict est `PASS_WITH_HERITED_DEBT` ou si parity-auditor liste des divergences héritées (préexistantes, hors scope du diff), **capture-les explicitement** dans le journal de feedback à l'étape 9 sous une section dédiée `## Dette héritée à résorber` :
   ```markdown
   ## Dette héritée à résorber (détectée par parity-auditor, hors scope)
   - <divergence 1>
   - <divergence 2>
   ```
   Cette section sera lue par `/feature-retro` pour proposer des patches sur `project-context.md` (durcir une convention, documenter la dette) ou suggérer une feature dédiée de rattrapage.

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

## Étape 7 — Mise à jour du contexte TECHNIQUE (OBLIGATOIRE)

Cette étape lutte contre l'obsolescence du `project-context.md`. Sans elle, le contexte technique fige une photo qui se périme à mesure que le projet évolue.

1. Lance l'agent `context-keeper` avec :
   - **Contexte** : « Analyse les diffs des sous-projets touchés par cette feature et propose des mises à jour ciblées de `.claude/project-context.md` selon les critères conservateurs définis dans ton prompt. Read-only. »

2. **Reçois son rapport**. Trois cas :

   **a) Rien à intégrer** (cas fréquent et normal) : le rapport indique « Aucun patch nécessaire ». Annonce-le au dev et passe à l'étape 8.

   **b) 1 à 5 patches proposés** : présente le rapport complet au dev. Puis pour chaque patch :

   > **Patch <N>** — [helper|ds-component|pattern|convention|dependency]
   > Justification : `<...>`
   >
   > ```diff
   > ...
   > ```
   >
   > Réponds : `apply` / `skip` / `edit : ...` / `stop`.

3. **Avant d'appliquer le premier patch validé**, crée un backup obligatoire :
   ```bash
   mkdir -p .claude/.context-backup
   cp .claude/project-context.md ".claude/.context-backup/$(date +%Y-%m-%d)-<slug>-before.md"
   ```

4. **Applique les patches validés** via Edit ciblé. Confirme chaque patch appliqué.

5. **Mets à jour le champ** `Dernière mise à jour automatique` de `project-context.md`.

6. Récap : « Contexte technique mis à jour : <n> patches appliqués sur <m> proposés. Backup : .claude/.context-backup/<date>-<slug>-before.md »

## Étape 8 — Mise à jour du contexte MÉTIER (OBLIGATOIRE)

Cette étape lutte contre l'obsolescence du `business-context.md`. Sans elle, la vue produit fige une photo qui se périme.

1. Lance l'agent `business-keeper` avec :
   - **Contexte** : « Analyse les diffs des sous-projets touchés par cette feature, le plan validé et la description initiale du dev. Propose des mises à jour ciblées de `.claude/business-context.md` selon les critères conservateurs définis dans ton prompt. Le patch `registry` (entrée dans le tableau des features livrées) est systématique sauf si la feature est purement technique. Read-only. »

2. **Reçois son rapport**. Cas typiques :

   **a) Patch registry seul** (cas le plus fréquent — la feature est livrée, on note ça mais sans plus) : présente le patch, applique-le après validation.

   **b) 1 à 6 patches proposés** (registry + autres patches métier) : présente le rapport complet. Pour chaque patch :

   > **Patch <N>** — [registry|screen|entity|state|flow|vocabulary|role|placeholder-fill]
   > Justification : `<...>`
   >
   > ```diff
   > ...
   > ```
   >
   > Réponds : `apply` / `skip` / `edit : ...` / `stop`.

   **c) Rien à intégrer** (feature purement technique) : annonce-le au dev et passe à l'étape 9.

3. **Avant d'appliquer le premier patch validé**, crée un backup obligatoire :
   ```bash
   mkdir -p .claude/.business-backup
   cp .claude/business-context.md ".claude/.business-backup/$(date +%Y-%m-%d)-<slug>-before.md"
   ```

4. **Applique les patches validés** via Edit ciblé. Confirme chaque patch appliqué.

5. **Mets à jour le champ** `Dernière mise à jour automatique` de `business-context.md` si présent.

6. Récap : « Contexte métier mis à jour : <n> patches appliqués sur <m> proposés. Backup : .claude/.business-backup/<date>-<slug>-before.md »

## Étape 9 — Capture du feedback (OBLIGATOIRE)

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

## Étape 10 — Clôture

Termine en demandant :

> Tu veux que je corrige les bloquants éventuels ? Tu veux que je commence le port iOS/Android (si la feature était scope api) ?

Si `.claude/feedback/` contient **5+ entrées non archivées**, ajoute :
> 💡 Tu as `<n>` journaux accumulés — bon moment pour lancer `/feature-retro` dès que tu auras 10 minutes.

Si la feature s'est mal passée et que tu veux tout annuler :
> Tu peux lancer `/feature-rollback` pour restaurer `project-context.md` et `business-context.md` depuis les backups, et archiver le journal de feedback de cette feature. Les commits des 3 repos ne seront pas touchés (à faire à la main via `git reset` si nécessaire).

## Règles d'orchestration

- **Gates humaines** : (1) après le plan, (2) à chaque patch context-keeper, (3) à chaque patch business-keeper. Pas d'autre gate pendant build/review.
- **Pré-vol git non bloquant** : avertis et continue.
- **Discovery déclenchée automatiquement** si `project-context.md` ou `business-context.md` est absent ou template-like.
- **Si un sub-agent échoue ou rend un output vide** : remonte au dev, ne tente pas de réparer toi-même.
- **En cas d'erreur 529 (overloaded) en cascade sur un builder** (≥ 2 échecs successifs à 0 tool calls) : ne relance pas une 3e fois automatiquement. Affiche au dev :
  > L'agent `<builder>` a échoué `<n>` fois consécutivement avec une erreur 529 (Anthropic API overloaded). Le travail partiel produit jusqu'ici est dans le diff git de `<dir>`. Trois options :
  > - **« continue »** : je tente une nouvelle fois (utile si la surcharge est intermittente)
  > - **« finish-manual »** : je liste précisément ce qu'il reste à faire (fichiers, erreurs build, étapes restantes) et tu finis à la main
  > - **« stop »** : on s'arrête là, le diff partiel reste, à toi de voir
  Si le dev choisit `finish-manual`, l'orchestrateur lit le diff partiel et le rapport partiel du builder, puis produit une liste précise des étapes restantes (fichiers à modifier avec snippets, erreurs TS à corriger, etc.) — sans appeler de sub-agent supplémentaire.
- **Si le build TS échoue dans api-builder** : api-builder doit corriger avant de rendre. Si persiste, remonte au dev.
- **Tu n'écris dans le projet** que (a) le journal de feedback en étape 9, (b) les patches context-keeper validés en étape 7, (c) les patches business-keeper validés en étape 8 (chacun avec backup obligatoire avant première application) — sinon délègue aux builders.
- **Tu ne commits jamais** sans accord explicite à l'étape 6.
- **Backups obligatoires** : `.claude/.context-backup/` pour les patches context-keeper, `.claude/.business-backup/` pour les patches business-keeper.

## Erreurs courantes à éviter

- Lancer api-builder sans « go » explicite du dev
- Sauter la discovery quand `project-context.md` ou `business-context.md` est absent / incomplet
- Laisser le dev deviner ce que fait chaque étape — annonce chaque transition
- Sauter la review parce que le build a passé — la review attrape les écarts de convention
- Modifier `CLAUDE.md` ou les fichiers d'agents pendant l'exécution
- Skipper la capture de feedback (étape 9)
- Skipper l'étape business-keeper (8) sous prétexte que la feature est « petite » — au minimum le patch registry doit être proposé
- Commiter automatiquement
- Mélanger les scopes (si scope `api` et le dev dit « ajoute aussi l'écran iOS », bascule en `api+mobile` proprement, ne fais pas du mobile en douce)
