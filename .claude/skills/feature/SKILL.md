---
name: feature
description: Implémente une feature dans un projet mobile natif + API Node/TS, de bout en bout. Orchestre la discovery (si nécessaire), le planning, la construction (API et/ou mobile selon scope), la review, et la capture obligatoire du feedback. Une seule gate humaine après le plan. Le système V1 implémente officiellement le scope api ; les scopes mobile et api+mobile s'appuient sur les squelettes V2 (ios-builder, android-builder, mobile-reviewer) et signalent au dev les limites.
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

Récupère le plan en sortie. Si le scope est `mobile` ou `api+mobile`, avertis le dev : « Cette feature touche le mobile. Le système V1 ne gère officiellement que le scope `api` ; ios-builder, android-builder et mobile-reviewer sont en squelette V2 et produiront un résultat partiel. Tu veux quand même continuer ou repositionner sur du backend uniquement ? »

## Étape 2 — Gate humaine (OBLIGATOIRE)

Affiche le plan **tel quel** dans la conversation, puis :

> Le plan ci-dessus est-il validé ? Réponds :
> - **« go »** pour lancer l'implémentation
> - **« revoir : ... »** pour demander une révision du plan (je relance le planner avec ton feedback)
> - **« stop »** pour annuler (aucun journal écrit)

**N'avance pas à l'étape 3 sans un « go » explicite.**

## Étape 3 — Implémentation (aiguillage par scope)

### Scope = `api`

Lance `api-builder` avec :
- **Plan complet** validé
- **Contexte** : « Implémente strictement le plan dans `<api-dir>` selon `project-context.md`. Compile avec la commande build du projet avant de rendre la main. Rapporte les fichiers touchés via `git -C <api-dir> status --short` et `git -C <api-dir> diff --stat`. »

Récupère le rapport du builder.

### Scope = `mobile`

Lance **en parallèle** `ios-builder` et `android-builder` avec :
- **Plan complet** validé
- **Contexte** : « Implémente la partie iOS (resp. Android) du plan selon `project-context.md`. Parité stricte avec l'autre plateforme. Compile avant de rendre. »

Note : ces agents sont en squelette V2 — le rapport sera moins riche. Signale au dev.

### Scope = `api+mobile`

Séquence : **api-builder d'abord**, puis (api fini) lance `ios-builder` et `android-builder` en parallèle.

Justification : les apps consomment l'API, donc l'API doit être prête (au moins en code, pas forcément déployée) avant que le mobile soit écrit.

## Étape 4 — Review

### Scope = `api`

Lance `api-reviewer` avec :
- **Plan validé** + **rapport builder** + **liste des fichiers touchés**
- **Contexte** : « Relis le delta git via `git -C <api-dir> diff`. Vérifie conformité à `CLAUDE.md` et `project-context.md`. Read-only. »

### Scope = `mobile`

Lance `mobile-reviewer` (V2 squelette — résultat partiel).

### Scope = `api+mobile`

Lance d'abord `api-reviewer` puis `mobile-reviewer`. Combine les deux rapports dans la synthèse.

## Étape 5 — Synthèse

Présente au dev en français concis :

1. **Résumé** : ce qui a été créé / modifié (3-5 puces, regroupé par sous-projet)
2. **Tests à passer** : commandes `curl` / actions UI fournies par les builders
3. **Verdict review** : PASS / PASS_WITH_MINOR_ISSUES / BLOCKED
4. **Bloquants** s'il y en a — avec proposition de relance du builder pour corriger
5. **TODO restant** : si scope `api` mais que la review signale du portage iOS/Android nécessaire, lister précisément ce qu'il faudra ajouter

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

## Étape 7 — Capture du feedback (OBLIGATOIRE)

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

## Étape 8 — Clôture

Termine en demandant :

> Tu veux que je corrige les bloquants éventuels ? Tu veux que je commence le port iOS/Android (si la feature était scope api) ?

Si `.claude/feedback/` contient **5+ entrées non archivées**, ajoute :
> 💡 Tu as `<n>` journaux accumulés — bon moment pour lancer `/feature-retro` dès que tu auras 10 minutes.

## Règles d'orchestration

- **Une seule gate humaine** après le plan (et 1 gate de validation discovery au premier `/feature`). Pas d'autre gate pendant build/review.
- **Pré-vol git non bloquant** : avertis et continue.
- **Discovery déclenchée automatiquement** si `project-context.md` absent.
- **Si un sub-agent échoue ou rend un output vide** : remonte au dev, ne tente pas de réparer toi-même.
- **Si le build TS échoue dans api-builder** : api-builder doit corriger avant de rendre. Si persiste, remonte au dev.
- **Tu n'écris jamais directement** dans les fichiers du projet (sauf le journal de feedback en étape 7) — délègue tout aux builders. Tu orchestres.
- **Tu ne commits jamais** sans accord explicite à l'étape 6.

## Erreurs courantes à éviter

- Lancer api-builder sans « go » explicite du dev
- Sauter la discovery quand `project-context.md` est absent
- Laisser le dev deviner ce que fait chaque étape — annonce chaque transition (« Discovery en cours… », « Plan reçu, je te le présente… », « Lancement du builder… »)
- Sauter la review parce que le build a passé — la review attrape les écarts de convention
- Modifier `CLAUDE.md` ou les fichiers d'agents pendant l'exécution
- Skipper la capture de feedback (étape 7)
- Commiter automatiquement
- Mélanger les scopes (si scope `api` et le dev dit « ajoute aussi l'écran iOS », bascule en `api+mobile` proprement, ne fais pas du mobile en douce)
