# Système d'agents — projets mobile natif + API Node/TS

Ce fichier est **générique** : il décrit la philosophie, le workflow et les invariants qui s'appliquent à **tout projet** suivant ce schéma :

- **iOS** : app native SwiftUI (dossier voisin)
- **Android** : app native Jetpack Compose (dossier voisin)
- **API** : Node.js + TypeScript (Express 5 / Fastify / NestJS), DB libre (MongoDB / PostgreSQL / Supabase / autre), auth JWT, dossier voisin

Les **conventions précises** de chaque projet (nommage du design system, codes d'erreur, helpers existants, etc.) vivent dans `.claude/project-context.md` — fichier généré automatiquement au premier `/feature` par l'agent `project-discoverer`, puis maintenu par les agents au fil des features.

**Règle d'or** : les agents lisent `CLAUDE.md` (ce fichier, philosophie) **et** `.claude/project-context.md` (spécifique au projet courant). Si `project-context.md` n'existe pas, ils s'arrêtent et déclenchent la discovery.

---

## Langue & style

- **Code en anglais** (identifiers, noms de fichiers, types)
- **Commentaires en français** pour les projets francophones — privilégier le « pourquoi », pas le « quoi »
- Pas de docstrings massifs ; explications courtes et ciblées
- Pas d'emojis dans le code

---

## Invariants de tout projet conforme

### Trois sous-projets, chacun son repo git, vivant n'importe où sur le disque

Le **workspace** Claude Code (où vit `CLAUDE.md`, `.claude/agents` symlink, `.claude/skills` symlink, `.claude/project-context.md`, `.claude/feedback/`) est **un dossier de config dédié**. Il **ne contient pas** les repos de code — il les **référence** via leurs chemins absolus, déclarés dans la section `## ⚠️ Chemins` de `project-context.md`.

```
<workspace>/                       ← dossier de config (point d'ancrage Claude Code)
├── CLAUDE.md                       (symlink vers le système)
└── .claude/
    ├── agents, skills              (symlinks vers le système)
    ├── project-context.md          (déclare api-dir, ios-dir, android-dir en absolu)
    ├── feedback/                   (journaux locaux)
    └── i18n-pending/               (clés de traduction collectées par feature, à importer manuellement)

/n/importe/où/sur/disque/api/      ← repo git API (chemin absolu déclaré)
/ailleurs/encore/ios/              ← repo git iOS
/dans/un/autre/coin/android/       ← repo git Android
```

Les chemins sont **renseignés à la main par le dev** dans `project-context.md` à l'installation. Le `project-discoverer` les **utilise** (ne les invente pas) pour scanner les sous-projets et compléter les autres champs.

Les agents utilisent toujours `git -C <chemin-absolu>` pour interroger un repo sans changer le cwd.

### Parité iOS ↔ Android

Objectif fort. Pour chaque feature touchant le mobile :

- **Mêmes noms** : écrans, ViewModels, composants design system, routes enum
- **Même UX** : même flow, même hiérarchie de navigation, mêmes états visuels
- **Mêmes endpoints API** appelés
- **Mêmes DTOs** structurés pareil (camelCase, mêmes suffixes)

Si une plateforme doit diverger pour raison technique (capacité OS, lib indisponible), c'est documenté en commentaire dans le code.

### Navigation par ID

**Règle absolue.**

> Un écran de détail reçoit un `id` en paramètre, **jamais** un objet pré-fetché. L'écran cible fetche / refresh ses propres données via cet ID.

**Pourquoi** : fraîcheur de la donnée, deep-linking, découplage des écrans.
**Signatures** : `onOpen<Screen>: (id: String) -> Unit`, `<Screen>DetailScreen(id: String)`.

### Design system maison

Tout projet conforme dispose d'un **design system maison** (boutons, cards, badges, inputs, etc.) **répliqué entre iOS et Android avec les mêmes noms**. Les agents ne créent jamais de composant UI brut (`Button(...)`, `Card(...)`) — ils utilisent ou étendent le design system du projet (lu dans `project-context.md`).

### Format API canonique

- **Succès** : `{ data: ... }`. Pour les listes paginées : `{ data: [...], pagination }`. Pour les actions : `204 No Content`.
- **Erreur** : `{ error: { code, message } }`, code en SCREAMING_SNAKE_CASE.
- **Auth** : JWT Bearer, decorators / middlewares au niveau du module ou de la route.
- **DTOs** : suffixes systématiques `Dto`, `RequestDto`, `ResponseXxxDto`, `MiniDto` (les suffixes exacts peuvent être surchargés dans `project-context.md`).

Si un projet a un format différent, c'est `project-context.md` qui le décrit et les agents s'adaptent.

---

## Scope d'une feature

Toute feature est classifiée par le `feature-planner` en un de ces trois scopes :

| Scope | Description | Agents impliqués |
|---|---|---|
| `api` | Touche uniquement l'API (ex. ajouter un endpoint admin, refactor backend) | feature-planner, api-builder, api-reviewer |
| `mobile` | Touche uniquement iOS + Android (ex. refonte UI, nouveau composant DS) — l'API existante couvre déjà le besoin | feature-planner, ios-builder, ios-reviewer, android-builder, android-reviewer, i18n-collector, parity-auditor, ds-guardian |
| `api+mobile` | Touche l'API et les apps (cas le plus courant) | tous |

Le planner **vérifie le contrat API existant** quand il évalue une feature `mobile`. Si l'API ne couvre pas le besoin, il bascule en `api+mobile`.

---

## Modes d'exécution d'une feature

Deux modes coexistent, choisis explicitement par le dev au moment d'invoquer `/feature` :

| Mode | Quand | Pipeline |
|---|---|---|
| `full` (défaut) | Feature nouvelle, écrans inédits, logique métier non triviale | planner → builders → reviewers → i18n-collector → parity-auditor → ds-guardian (scoped) → context-keeper → business-keeper → feedback |
| `light` | Refactor pur (renommage, déplacement), feature très simple (1 écran ou filtre local), série de petites features bundlées | (questions directes au dev, pas de planner formel) → builders en série → context-keeper en batch → business-keeper en batch → feedback unique. Pas de reviewers, pas de i18n-collector, pas de parity-auditor, pas de ds-guardian. Audit reporté à `/feature-retro` ou à la prochaine feature `full`. |

**Quand suggérer le mode `light` au dev** :
- La description contient « refactor pur », « renommage », « aucun changement de comportement métier », ou similaire
- La feature touche un seul écran simple ou un seul filtre local
- Le dev demande un bundle de 2+ features en série

Si le mode n'est pas précisé, prendre `full` par défaut mais signaler la possibilité du mode `light` quand l'un des critères ci-dessus est rencontré.

---

## Workflow `/feature`

```
/feature "<description>"
   │
   ├─ Pré-vol :
   │    • project-context.md existe et chemins renseignés ? non → lancer project-discoverer
   │    • repos git propres ? non → avertissement (non bloquant)
   │
   ├─ Étape 1 : feature-planner → plan (DB / routes / écrans iOS / écrans Android / scope)
   │
   ├─ GATE HUMAINE : go / revoir / stop
   │
   ├─ Étape 2 : selon scope
   │    • api        → api-builder → api-reviewer
   │    • mobile     → ios-builder → ios-reviewer → android-builder → android-reviewer → i18n-collector → parity-auditor → ds-guardian (scoped)
   │    • api+mobile → api-builder → api-reviewer → ios-builder → ios-reviewer → android-builder → android-reviewer → i18n-collector → parity-auditor → ds-guardian (scoped)
   │
   │   Note : le workflow mobile est SÉQUENTIEL et iOS d'abord. android-builder
   │   utilise le code iOS qui vient d'être produit comme spec implicite pour
   │   garantir la parité (mêmes noms d'écrans, mêmes composants DS, même flow).
   │   android-reviewer relit également le code iOS pour vérifier l'alignement.
   │   i18n-collector extrait les nouvelles clés de traduction introduites par
   │   la feature (scan des invocations dans le diff iOS+Android) et dépose un
   │   fichier .strings par langue active dans <workspace>/.claude/i18n-pending/
   │   — outil-agnostique (le dev importe ensuite dans Crowdin / Lokalise /
   │   autre). Si l'i18n n'est pas implémentée sur le projet (section i18n du
   │   project-context.md = `non implémentée`), l'agent rend immédiatement
   │   EMPTY et n'écrit rien.
   │   parity-auditor termine la séquence avec un audit complet du domaine
   │   fonctionnel touché (pas juste le delta) pour détecter aussi les
   │   divergences héritées qui se sont accumulées au fil des features —
   │   y compris les divergences de clés i18n signalées par i18n-collector.
   │
   ├─ Étape 3 : synthèse au dev (fichiers touchés, tests, verdict review)
   │
   ├─ Étape 4 : proposition de commit (1 par repo touché, message standardisé)
   │
   ├─ Étape 5 : context-keeper
   │   Analyse les diffs et propose jusqu'à 5 patches ciblés sur
   │   .claude/project-context.md (helpers réutilisables, composants DS,
   │   patterns d'archi confirmés — conservateur). Patches validés un par un.
   │   Backup auto dans .claude/.context-backup/ avant la première application.
   │
   ├─ Étape 6 : business-keeper
   │   Analyse les diffs + le plan + la description et propose des patches
   │   ciblés sur .claude/business-context.md (registre de la feature livrée
   │   — systématique, nouveaux écrans, nouvelles entités, flows, vocabulaire,
   │   états). Patches validés un par un. Backup auto dans .claude/.business-backup/.
   │   Maintient la vue produit à jour. Annulable via /feature-rollback.
   │
   └─ Étape 7 : CAPTURE FEEDBACK OBLIGATOIRE
        Format : 5 notes 1-5 + 2 textes libres + stats git
        Journal écrit dans .claude/feedback/YYYY-MM-DD-<slug>.md
```

---

## Capture de feedback (obligatoire en fin de chaque `/feature`)

À la fin de chaque feature, le skill **doit** capturer le feedback du dev humain. Sans ça, `/feature-retro` n'a rien à exploiter et le système ne progresse pas.

### Formulaire affiché

```
📊 Notes (1=mauvais, 5=excellent) :
- Qualité du plan          : ?/5
- Conformité du code livré : ?/5
- Pertinence de la review  : ?/5
- Effort manuel post-livraison (1=énorme, 5=rien à toucher) : ?/5
- Gain de temps ressenti   : ?/5

✍️ Texte libre :
- Qu'as-tu dû corriger à la main (le cas échéant) ?
- Qu'est-ce qu'on aurait dû détecter / mieux faire plus tôt ?
```

### Format du journal

```markdown
---
date: YYYY-MM-DD
slug: <kebab-case>
feature: "<description originale>"
scope: api | mobile | api+mobile
revoirs: <n tours planner>
build_attempts: <n>
review_verdict: PASS | PASS_WITH_MINOR_ISSUES | BLOCKED
commits:
  api: <hash ou null>
  ios: <hash ou null>
  android: <hash ou null>
scores:
  plan: <1-5>
  code: <1-5>
  review: <1-5>
  effort_post: <1-5>
  gain_time: <1-5>
---

## Description initiale
<phrase du dev>

## Plan validé (résumé en 3-5 puces)
- ...

## Écarts plan ↔ code
- ... (ou « aucun »)

## Verdict de la review
- Bloquants : <n>
- Sérieux : <n>
- Améliorations : <n>
- Détail des sérieux : <liste courte>

## Dette héritée à résorber (détectée par parity-auditor / ds-guardian, hors scope)
<liste, ou « aucune »>

## Corrections manuelles post-livraison (verbatim du dev)
<texte, ou « ras »>

## Détection à améliorer (verbatim du dev)
<texte, ou « ras »>

## Stats git
- API : <diff --stat>
- iOS : <diff --stat ou « non touché »>
- Android : <diff --stat ou « non touché »>

## Fichiers touchés
- <chemin> (créé/modifié)
```

---

## Workflow `/feature-retro`

Lancé manuellement par le dev. Lit les journaux non archivés dans `.claude/feedback/`, identifie les patterns récurrents (signal apparaît ≥ 2 fois), et produit jusqu'à 8 patches en diff sur :

- `project-context.md` du projet (conventions à durcir ou clarifier)
- Les agents génériques (uniquement si le pattern est cross-project)
- `CLAUDE.md` générique (uniquement si le pattern est vraiment fondamental)

**Important** : un patch sur les agents génériques ou sur `CLAUDE.md` affecte **tous les projets** consommateurs. Le retro doit le signaler explicitement et demander confirmation supplémentaire avant application.

Patches validés un par un via `/feature-retro`. Journaux archivés à la fin (renommés en `*.archived.md`).

---

## Utilisation de git

Tous les agents et skills exploitent les repos git de chaque sous-projet :

- **Pré-vol** : `git -C <dir> status --porcelain` est inspecté avant `/feature`. Si non vide, le skill **avertit** le dev (« attention, des modifications non commitées sont déjà présentes dans <dir>, le diff de cette feature pourra être imprécis ») et continue. Pas de blocage, libre au dev de stash/commit avant ou de laisser couler.
- **api-builder, ios-builder, android-builder** : à la fin, `git -C <dir> status --short` et `git -C <dir> diff --stat` pour rapporter exactement ce qui a été touché
- **api-reviewer, ios-reviewer, android-reviewer** : commencent par `git -C <dir> diff --name-only` puis `git -C <dir> diff <fichier>` ciblé — review du delta, pas du fichier entier. `android-reviewer` lit aussi `git -C <ios-dir> diff` pour vérifier la parité.
- **Commit** : proposé en fin de feature au dev, **jamais** fait automatiquement. Format suggéré : `feat(<scope>): <slug>` ou `fix(<scope>): <slug>` selon le contexte
- **Hash de commit** : capturé dans le journal de feedback si le dev a commit avant de répondre au formulaire

Les agents utilisent **toujours** `git -C <dir>` pour ne pas changer le cwd entre commandes.

---

## Périmètre d'écriture

Chaque agent a un périmètre limité :

| Agent | Peut écrire dans |
|---|---|
| project-discoverer | `.claude/project-context.md` uniquement |
| feature-planner | rien (read-only) |
| api-builder | `<api-dir>/` selon `project-context.md` (sources, types, migrations) |
| api-reviewer | rien (read-only) |
| ios-builder | `<ios-dir>/` (sources Swift, DTOs, store, écrans, DS) |
| ios-reviewer | rien (read-only) |
| android-builder | `<android-dir>/` (sources Kotlin, DTOs Retrofit, VM, écrans, DS) |
| android-reviewer | rien (read-only) — lit aussi `<ios-dir>/` pour vérifier la parité |
| i18n-collector | `<workspace>/.claude/i18n-pending/<date>-<slug>/` uniquement — read-only sur `<ios-dir>/` et `<android-dir>/`, lit le diff git pour extraire les nouvelles clés de traduction |
| parity-auditor | rien (read-only) — lit `<ios-dir>/` ET `<android-dir>/`, audite l'ensemble du domaine touché (y compris les clés i18n collectées par i18n-collector) |
| ds-guardian | rien (read-only) — audite l'usage et la santé du design system (modes scoped et full) |
| context-keeper | rien (read-only, propose des patches sur `.claude/project-context.md`) — contexte TECHNIQUE |
| business-keeper | rien (read-only, propose des patches sur `.claude/business-context.md`) — contexte MÉTIER (vue produit) |
| system-retrospective | rien (read-only, propose des diffs) |

Tout agent qui tenterait d'écrire hors de son périmètre doit refuser et signaler.

---

## Ce qu'il ne faut PAS faire (transverse)

- Ne pas commit automatiquement (toujours laisser le dev choisir)
- Ne pas modifier `CLAUDE.md` générique depuis une retro projet sans confirmation **explicite** que c'est un pattern cross-projets
- Ne pas inventer une convention non présente dans `project-context.md` — préférer demander
- Ne pas écrire iOS sans Android (ou inversement) pour une feature `mobile` ou `api+mobile`
- Ne pas skipper la capture de feedback à la fin d'un `/feature`
- Ne pas dépasser le périmètre d'écriture défini

---

## Référence : qu'est-ce qui vit où ?

| Fichier | Localisation | Propriétaire |
|---|---|---|
| `CLAUDE.md` (générique) | repo `~/work/claude-mobile-agents/` | partagé entre projets |
| `.claude/agents/*.md` | repo `~/work/claude-mobile-agents/` | partagé entre projets |
| `.claude/skills/*/SKILL.md` | repo `~/work/claude-mobile-agents/` | partagé entre projets |
| `.claude/project-context.md` | projet local | propre au projet |
| `.claude/feedback/*.md` | projet local | propre au projet |
| `.claude/i18n-pending/<date>-<slug>/*.strings` | projet local | propre au projet (généré par `i18n-collector`) |

Le `install.sh` du repo crée les symlinks corrects dans chaque projet consommateur.
