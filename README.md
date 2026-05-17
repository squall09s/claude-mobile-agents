# claude-mobile-agents

Système d'agents Claude Code pour développer des features de bout en bout dans des projets **mobile natif + API Node/TS**.

Conçu pour des projets qui suivent ce schéma :

- **iOS natif** (SwiftUI) — dans un dossier voisin
- **Android natif** (Jetpack Compose) — dans un dossier voisin
- **API Node + TypeScript** (Express 5 / Fastify / NestJS) — dans un dossier voisin
- Chacun a son propre repo git
- DB libre (MongoDB, PostgreSQL, Supabase, autre), auth JWT, design system maison répliqué iOS/Android avec parité forte

## Ce que fait le système

Deux skills Claude Code :

### `/feature "<description>"`

Implémente une feature de bout en bout :

1. **Discovery automatique** au premier lancement sur un projet — scanne la stack, génère `.claude/project-context.md` à valider
2. **Planification** par `feature-planner` (détermine le scope : `api` / `mobile` / `api+mobile`)
3. **Gate humaine** sur le plan (`go` / `revoir` / `stop`)
4. **Construction** selon scope :
   - `api` → `api-builder` + `api-reviewer`
   - `mobile` → `ios-builder` + `android-builder` (parallèle) + `mobile-reviewer` *(V2)*
   - `api+mobile` → API d'abord, puis mobile *(V2 pour le mobile)*
5. **Synthèse** au dev (fichiers touchés, tests, verdict review)
6. **Proposition de commit** par sous-projet (jamais auto)
7. **Capture de feedback obligatoire** : 5 notes + 2 textes libres → journal dans `.claude/feedback/`

### `/feature-retro`

Améliore le système à partir des journaux accumulés :

1. **Analyse** par `system-retrospective` (lit les journaux non archivés)
2. **Patches proposés** en diff, classés `projet` (local) ou `système` (générique, partagé)
3. **Validation un par un** par le dev (`apply` / `skip` / `edit` / `stop`)
4. **Application** des patches validés (Edit ciblé)
5. **Commit optionnel** du repo système si des patches `système` ont été appliqués
6. **Archivage optionnel** des journaux exploités

## Architecture

```
~/work/claude-mobile-agents/          ← ce repo (versionné, partagé entre projets)
├── README.md                          ← ce fichier
├── install.sh                         ← installe le système dans un projet (symlinks)
├── CLAUDE.md                          ← philosophie générique (parité, workflow, journal)
├── templates/
│   └── project-context.md.template    ← gabarit utilisé par project-discoverer
└── .claude/
    ├── agents/
    │   ├── project-discoverer.md      ← auto-détection de stack (au premier /feature)
    │   ├── feature-planner.md         ← plan + scope (api/mobile/api+mobile)
    │   ├── api-builder.md             ← Node+TS multi-framework
    │   ├── api-reviewer.md            ← review via git diff
    │   ├── ios-builder.md             ← (V2 — squelette)
    │   ├── android-builder.md         ← (V2 — squelette)
    │   ├── mobile-reviewer.md         ← (V2 — squelette)
    │   └── system-retrospective.md    ← propose des patches (projet/système)
    └── skills/
        ├── feature/SKILL.md
        └── feature-retro/SKILL.md
```

Dans chaque projet consommateur :

```
<projet>/
├── CLAUDE.md                 → symlink vers ce repo
└── .claude/
    ├── agents/               → symlink vers ce repo
    ├── skills/               → symlink vers ce repo
    ├── project-context.md    ← LOCAL : généré par project-discoverer, spécifique au projet
    └── feedback/             ← LOCAL : journaux de ce projet uniquement
```

## Installation sur un nouveau projet

```bash
cd /chemin/vers/mon/projet
bash ~/work/claude-mobile-agents/install.sh
```

Le script :

1. Sauvegarde les éventuels `CLAUDE.md` / `.claude/agents/` / `.claude/skills/` existants (suffixe `.backup.YYYYMMDD-HHMMSS`)
2. Pose les symlinks
3. Crée `.claude/feedback/` local si absent
4. Affiche les prochaines étapes

Puis, à la racine du projet, lance Claude Code et :

```
/feature "ma première feature"
```

Au premier lancement, `project-discoverer` scanne le projet et génère `.claude/project-context.md`. Tu le valides en 2 min, puis le workflow normal démarre.

## Périmètres d'écriture (sécurité)

Chaque agent a un périmètre verrouillé :

| Agent | Écrit dans |
|---|---|
| `project-discoverer` | `.claude/project-context.md` uniquement |
| `feature-planner` | rien (read-only) |
| `api-builder` | `<api-dir>/` (chemin lu dans `project-context.md`) |
| `api-reviewer` | rien (read-only) |
| `ios-builder` *(V2)* | `<ios-dir>/` |
| `android-builder` *(V2)* | `<android-dir>/` |
| `mobile-reviewer` *(V2)* | rien (read-only) |
| `system-retrospective` | rien (propose des diffs, c'est `/feature-retro` qui applique) |

Aucun agent ne commit automatiquement — toujours proposé au dev, jamais imposé.

## Boucle d'apprentissage

Le système est conçu pour s'améliorer à chaque feature :

1. Chaque `/feature` se termine par une **capture de feedback obligatoire** (5 notes + 2 textes libres)
2. Le journal est écrit dans `.claude/feedback/<date>-<slug>.md`
3. Quand 3+ journaux sont accumulés, le dev lance `/feature-retro`
4. Les patterns récurrents (signal ≥ 2 fois) génèrent des **patches** :
   - **Projet** : durcissent `.claude/project-context.md` du projet courant
   - **Système** : améliorent les agents pour tous les projets consommateurs (avec confirmation supplémentaire)
5. Patches validés un par un → appliqués via Edit → optionnellement commit du repo système

## Mise à jour du système

Le repo est versionné. Pour pull les améliorations :

```bash
cd ~/work/claude-mobile-agents
git pull
```

Tous les projets qui ont les symlinks pointant vers ce repo reçoivent immédiatement la nouvelle version (rien à faire côté projet).

## Pré-requis

- **Claude Code** (CLI, app desktop, web, ou IDE — tous compatibles)
- **Node ≥ 20** et `npm` (pour `api-builder` qui compile)
- **Git** (3 repos git attendus dans le projet : api, ios, android)
- **Xcode** pour les builds iOS *(V2)*
- **Gradle / Android Studio** pour les builds Android *(V2)*

## État actuel — V1

✅ **Scope `api` pleinement fonctionnel** : planner, builder, reviewer, retro, capture feedback, discovery
🚧 **Scope `mobile` et `api+mobile`** : ios-builder, android-builder, mobile-reviewer en squelettes — produiront un résultat partiel jusqu'à la V2

Le système avertit le dev quand il détecte un scope mobile et propose de soit continuer en mode partiel, soit recentrer la feature sur du backend.

## Roadmap V2

- Compléter `ios-builder` avec connaissance fine de SwiftUI + adaptation au pattern d'archi du projet
- Compléter `android-builder` avec connaissance fine de Compose + parité stricte iOS
- Compléter `mobile-reviewer` avec checklist parité iOS↔Android
- Ajouter un agent `parity-auditor` qui compare le code iOS et Android après les builders

## Licence

Privé — usage personnel.
