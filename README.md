# 🛸 claude-mobile-agents

Système d'agents Claude Code pour livrer des features de bout en bout sur des projets **mobile natif + API Node/TS**. Les agents exécutent, le développeur orchestre et valide.

Conçu pour des projets qui suivent ce schéma :

- **iOS natif** (SwiftUI) — repo dédié
- **Android natif** (Jetpack Compose) — repo dédié
- **API Node + TypeScript** (Express 5 / Fastify / NestJS) — repo dédié
- DB libre (MongoDB, PostgreSQL, Supabase, autre), auth JWT
- Design system maison répliqué iOS/Android, parité stricte

---

## 🧑‍🚀 Les agents

Deux commandes sont accessibles depuis Claude Code.

### `/feature "<description>"`

Implémente une feature de bout en bout :

1. **Discovery** au premier passage sur un projet — `project-discoverer` lit les chemins absolus déclarés puis complète `.claude/project-context.md` à partir du code scanné
2. **Plan technique** par `feature-planner` (détermine le scope : `api` / `mobile` / `api+mobile`)
3. **Gate humaine** sur le plan (`go` / `revoir` / `stop`)
4. **Construction** selon scope :
   - `api` → `api-builder` puis `api-reviewer`
   - `mobile` → séquentiel : `ios-builder` → `ios-reviewer` → `android-builder` → `android-reviewer` → `parity-auditor`. Android porte le code iOS pour garantir la parité.
   - `api+mobile` → API d'abord, puis la séquence mobile complète
5. **Synthèse** au développeur (fichiers touchés, tests, verdict review, audit parité)
6. **Proposition de commit** par sous-projet — jamais automatique
7. **Mise à jour du contexte projet** par `context-keeper` : propose jusqu'à 5 patches ciblés sur `.claude/project-context.md` (helpers réutilisables, composants DS, patterns d'archi confirmés). Patches validés un par un. Backup automatique avant application.
8. **Journal de bord obligatoire** : 5 notes + 2 retours libres, archivé dans `.claude/feedback/`

### `/feature-retro`

Améliore le système à partir des journaux accumulés. À partir de 3 journaux :

1. **Analyse** par `system-retrospective` — lecture des journaux non archivés
2. **Patches proposés** sous forme de diff, classés `projet` (locaux au projet courant) ou `système` (impactent tous les projets consommateurs)
3. **Validation patch par patch** (`apply` / `skip` / `edit` / `stop`)
4. **Application** des patches retenus
5. **Commit optionnel** du repo système si des patches `système` ont été appliqués
6. **Archivage** des journaux exploités

### `/feature-rollback`

Annule les traces de la dernière `/feature` lorsqu'elle s'est mal passée :

1. **Restaure** `.claude/project-context.md` depuis le dernier backup créé par `context-keeper`
2. **Archive** le dernier journal de feedback en `.rolled-back.md` (ignoré par `/feature-retro`)
3. **Ne touche pas aux commits git** des trois repos (à gérer à la main via `git reset` si nécessaire)
4. Confirmation explicite avant chaque étape — granularité possible (`ok` / `contexte seul` / `journal seul` / `stop`)

### `/ds-audit`

Audit complet du design system du projet (côté iOS + Android), en mode standalone :

1. **Bypass** : Button/TextField/Color bruts utilisés sur les écrans au lieu du design system
2. **Doublons** : composants DS quasi-identiques, orphelins, sous-utilisés
3. **Cohérence iOS↔Android** : signatures et styles fins qui divergent sans raison documentée
4. **Suggestions** : nouveaux composants DS à créer quand un pattern brut se répète

Read-only — produit un rapport, suggère des features de refacto. À lancer périodiquement (mensuel ou après une période d'ajout intensif d'écrans). Une version allégée (`ds-guardian` en mode scoped) tourne automatiquement à la fin de chaque `/feature` mobile pour empêcher l'introduction de nouvelle dette DS.

---

## 🛰️ Architecture

Le repo système (versionné, partagé entre tous les projets) :

```
~/work/claude-mobile-agents/
├── README.md
├── install.sh                            ← script d'installation par projet
├── CLAUDE.md                             ← philosophie générique
├── templates/
│   └── project-context.md.template       ← gabarit du registre projet
└── .claude/
    ├── agents/
    │   ├── project-discoverer.md         ← scout : complète project-context.md
    │   ├── feature-planner.md            ← stratège : plan + scope
    │   ├── api-builder.md                ← ingénieur API (Node+TS multi-framework)
    │   ├── api-reviewer.md               ← inspecteur API (review via git diff)
    │   ├── ios-builder.md                ← ingénieur iOS (SwiftUI)
    │   ├── ios-reviewer.md               ← inspecteur iOS (review + brief pour Android)
    │   ├── android-builder.md            ← ingénieur Android (Compose, porte le code iOS)
    │   ├── android-reviewer.md           ← inspecteur Android (review + audit parité delta)
    │   ├── parity-auditor.md             ← auditeur parité (vue complète du domaine)
    │   ├── ds-guardian.md                ← gardien du design system (bypass, doublons, cohérence)
    │   ├── context-keeper.md             ← gardien du project-context.md (lutte contre l'obsolescence)
    │   └── system-retrospective.md       ← analyste : propose des améliorations
    └── skills/
        ├── feature/SKILL.md
        ├── feature-retro/SKILL.md
        ├── feature-rollback/SKILL.md
        └── ds-audit/SKILL.md
```

Chaque projet dispose d'une workspace de commande locale :

```
<workspace>/
├── CLAUDE.md                  → symlink vers le repo système
└── .claude/
    ├── agents/                → symlink vers le repo système
    ├── skills/                → symlink vers le repo système
    ├── project-context.md     ← local : stack et conventions du projet
    ├── .context-backup/        ← local : backups avant modifs context-keeper (pour /feature-rollback)
    └── feedback/              ← local : journaux du projet
```

---

## 🚀 Installation sur un nouveau projet

> **Modèle « workspace de config »**
> Le workspace Claude est un dossier dédié à la configuration. Il **ne contient pas** les trois repos (iOS, Android, API) — il les **référence** via leurs chemins absolus, déclarés dans `project-context.md`. Les repos restent à leur emplacement habituel sur le disque.

### Étape 1 — Préparer le workspace

Choisir un emplacement pour la config Claude, séparé des repos de code. Recommandation : un dossier dédié par projet.

```bash
mkdir -p ~/Claude/MyApp
cd ~/Claude/MyApp
```

Le nom du dossier est libre. C'est le **cwd** depuis lequel Claude Code sera lancé.

### Étape 2 — Installer les agents

```bash
bash ~/work/claude-mobile-agents/install.sh
```

Le script :

1. Sauvegarde les éventuels `CLAUDE.md` / `.claude/agents` / `.claude/skills` existants (suffixe `.backup.YYYYMMDD-HHMMSS`)
2. Pose les symlinks vers le repo système
3. Crée `.claude/feedback/` local
4. Copie le template `project-context.md.template` dans `.claude/project-context.md`
5. Saisie interactive des coordonnées des trois repos (chemins absolus, validés à la volée)

### Étape 3 — Déclarer les coordonnées des repos

Pendant l'install, trois prompts successifs :

```
  ➤ API  (api-dir)
    Exemple : /Users/nico/Code/MyApp-API
    Chemin absolu : _

  ➤ iOS  (ios-dir)
    ...

  ➤ Android  (android-dir)
    ...
```

Règles de saisie :

- **Chemins absolus uniquement** (commencent par `/`). Le `~` est étendu automatiquement.
- Chaque dossier doit exister et contenir son propre `.git/` (avertissement non bloquant sinon).
- **Enter vide** = composant absent (ex. backend-only) → placeholder conservé.
- Modification possible plus tard en éditant `.claude/project-context.md` à la main.

### Étape 4 — Première feature

```bash
cd ~/Claude/MyApp       # le workspace, pas l'un des repos de code
# (lancer Claude Code ici — terminal, app desktop, ou web)
/feature "première feature"
```

Au premier passage, `project-discoverer` lit les trois chemins, scanne les dossiers pour extraire la stack (framework API, design system iOS, etc.) et complète `project-context.md`. Le développeur valide en 2 min, le workflow normal s'enchaîne.

### Cas particulier — Repos déjà sous un dossier commun

Pour une structure existante du type :

```
~/Code/MyApp/
├── MyAppAPI/
├── MyAppIOS/
└── MyAppAndroid/
```

`~/Code/MyApp/` peut servir directement de workspace (lancer `install.sh` dedans). Les chemins absolus pointeront vers ses sous-dossiers.

---

## 🛡️ Périmètres d'écriture

Chaque agent opère dans un périmètre verrouillé.

| Agent | Périmètre d'écriture |
|---|---|
| `project-discoverer` | `.claude/project-context.md` uniquement |
| `feature-planner` | rien (read-only) |
| `api-builder` | `<api-dir>/` (lu dans `project-context.md`) |
| `api-reviewer` | rien (read-only) |
| `ios-builder` | `<ios-dir>/` |
| `ios-reviewer` | rien (read-only) |
| `android-builder` | `<android-dir>/` |
| `android-reviewer` | rien (read-only) — lit aussi `<ios-dir>/` pour vérifier la parité |
| `parity-auditor` | rien (read-only) — lit `<ios-dir>/` ET `<android-dir>/` pour auditer le domaine |
| `ds-guardian` | rien (read-only) — audite le design system (modes scoped et full) |
| `context-keeper` | rien (read-only) — propose des patches sur `.claude/project-context.md`, le skill `/feature` applique après validation |
| `system-retrospective` | rien (propose des diffs, `/feature-retro` applique) |

**Aucun agent ne commit automatiquement.** Tout commit est proposé au développeur, jamais imposé.

---

## 🧠 Boucle d'apprentissage

Le système devient meilleur à chaque feature, sur deux axes :

**Axe 1 — Mise à jour continue du contexte** (à chaque `/feature`)

À la fin de chaque feature, `context-keeper` analyse les diffs et propose jusqu'à 5 patches conservateurs sur `.claude/project-context.md` (helpers réutilisables, nouveaux composants DS, patterns d'archi confirmés). Patches validés un par un, avec backup automatique avant application. Lutte directe contre l'obsolescence du contexte projet.

**Axe 2 — Évolution du système** (via `/feature-retro`, occasionnellement)

1. Chaque `/feature` se termine par un journal de bord obligatoire (5 notes + 2 retours libres)
2. Le journal est archivé dans `.claude/feedback/<date>-<slug>.md`
3. Quand 3 journaux ou plus s'accumulent, le déclenchement de `/feature-retro` devient pertinent
4. Les patterns récurrents (signal présent au moins deux fois) déclenchent des patches :
   - **Projet** : durcissent `.claude/project-context.md` du projet courant
   - **Système** : améliorent les agents pour tous les projets futurs (confirmation supplémentaire requise)
5. Patches validés un par un → appliqués → commit optionnel du repo système

---

## 🧰 Prérequis

- **Claude Code** (CLI, app desktop, app web, ou IDE — tous compatibles)
- **Node ≥ 20** et `npm` (pour `api-builder` qui compile)
- **Git** (trois repos git attendus par projet : api, ios, android)
- **Xcode** pour les builds iOS (utilisé par `ios-builder` et `ios-reviewer`)
- **Gradle / Android Studio** pour les builds Android (utilisé par `android-builder` et `android-reviewer`)

---

## ✅ État — V2

Tous les scopes opérationnels :

- **`api`** — discovery, planificateur, builder API, reviewer API
- **`mobile`** — builder iOS (SwiftUI), reviewer iOS, builder Android (Compose, porte le code iOS), reviewer Android (audit parité delta), parity-auditor (audit parité complète du domaine), ds-guardian scoped (vérifie le respect fin du design system sur les fichiers touchés)
- **`api+mobile`** — séquence complète : API puis mobile (iOS d'abord, Android ensuite, audit parité, audit DS)
- **context-keeper** à la fin de chaque feature pour maintenir `.claude/project-context.md` à jour
- **/ds-audit** standalone pour un audit complet du design system du projet
- **/feature-rollback** pour annuler les traces de la dernière feature en cas de problème
- Journal de bord obligatoire à chaque feature, rétrospective via `/feature-retro`

Le workflow mobile est **séquentiel** : iOS implémenté en premier, son code sert de spec implicite à Android. `android-reviewer` audite la parité du delta, `parity-auditor` audite la parité complète du domaine fonctionnel (incluant les divergences héritées accumulées).

---

## 🛰️ Roadmap (idées)

- Agent `test-author` pour générer des tests d'intégration API après chaque feature `api`
- Agent `snapshot-tester-ds` pour des snapshot tests des composants du design system (iOS via swift-snapshot-testing, Android via Paparazzi/Roborazzi)
- Génération automatique de DTOs partagés via OpenAPI pour réduire la duplication TS / Swift / Kotlin
- Mode `--watch` pour `/feature-retro` qui surveille l'accumulation de divergences héritées dans plusieurs domaines et propose des features de remise à niveau
- Agents qualité transverses : `performance-auditor`, `a11y-auditor`, `security-scanner`

---

## 📜 Licence

[MIT](LICENSE) — utilisation libre, modification, distribution autorisées. Aucune garantie.
