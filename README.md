# 🛸 claude-mobile-agents

> *« Vous êtes le capitaine. Voici votre équipage. »*

Une flotte d'agents Claude Code spécialisés, prête à embarquer pour livrer des features de bout en bout sur des projets **mobile natif + API Node/TS**. Tu donnes une mission, ils s'occupent du reste — et toi, tu pilotes.

🪐 **Conçu pour des projets qui suivent ce schéma** :

- 🍎 **iOS natif** (SwiftUI) — son propre repo
- 🤖 **Android natif** (Jetpack Compose) — son propre repo
- ⚡ **API Node + TypeScript** (Express 5 / Fastify / NestJS) — son propre repo
- 🗄️ DB libre (MongoDB, PostgreSQL, Supabase, autre), auth JWT
- 🎨 Design system maison répliqué iOS/Android avec parité forte

---

## 🧑‍🚀 L'équipage

Deux **commandes vocales** (skills) sont à ta disposition depuis la passerelle (Claude Code).

### 🎯 `/feature "<description>"` — lancer une mission

L'équipage se met en branle pour livrer la feature de bout en bout :

1. 🔭 **Reconnaissance** au premier passage sur un projet — `project-discoverer` scanne la stack et complète `.claude/project-context.md` à partir de tes chemins absolus
2. 📋 **Briefing** par `feature-planner` (détermine le scope : `api` / `mobile` / `api+mobile`)
3. 🛡️ **Validation capitaine** sur le plan (`go` / `revoir` / `stop`)
4. ⚙️ **Construction** selon scope :
   - `api` → `api-builder` + `api-reviewer`
   - `mobile` → `ios-builder` + `android-builder` (parallèle) + `mobile-reviewer` *(V2)*
   - `api+mobile` → API d'abord, puis mobile *(V2 pour le mobile)*
5. 📊 **Compte-rendu** au capitaine (fichiers touchés, tests, verdict review)
6. 💾 **Proposition de commit** par sous-projet (jamais auto — c'est ta signature qui scelle)
7. 📓 **Journal de bord obligatoire** : 5 notes + 2 retours libres → archivé dans `.claude/feedback/`

### 🧠 `/feature-retro` — faire grandir l'équipage

L'équipage apprend de ses missions. À partir de 3 journaux de bord, lance la rétrospective :

1. 🔍 **Analyse** par `system-retrospective` (lit les journaux non archivés)
2. 🛠️ **Améliorations proposées** en diff, classées `projet` (local à ta mission courante) ou `système` (affecte toute la flotte)
3. 🛡️ **Validation patch par patch** (`apply` / `skip` / `edit` / `stop`)
4. ⚡ **Déploiement** des patches retenus
5. 💾 **Commit optionnel** du repo système si des patches `système` ont été appliqués
6. 🗃️ **Archivage** des journaux exploités

---

## 🛰️ Architecture de la flotte

```
~/work/claude-mobile-agents/                ← le vaisseau-mère (versionné, partagé)
├── README.md                                ← ce que tu lis
├── install.sh                                ← module d'embarquement
├── CLAUDE.md                                ← philosophie générique (parité, workflow, journal)
├── templates/
│   └── project-context.md.template          ← gabarit du registre de mission
└── .claude/
    ├── agents/
    │   ├── 🔭 project-discoverer.md         ← scout : complète project-context.md
    │   ├── 📋 feature-planner.md             ← stratège : plan + scope
    │   ├── ⚡ api-builder.md                 ← ingénieur API (Node+TS multi-framework)
    │   ├── 🛡️ api-reviewer.md                ← inspecteur API (review via git diff)
    │   ├── 🍎 ios-builder.md                 ← ingénieur iOS (V2 — squelette)
    │   ├── 🤖 android-builder.md             ← ingénieur Android (V2 — squelette)
    │   ├── 🛡️ mobile-reviewer.md             ← inspecteur mobile (V2 — squelette)
    │   └── 🧠 system-retrospective.md        ← analyste : propose des améliorations
    └── skills/
        ├── feature/SKILL.md                   ← commande de mission
        └── feature-retro/SKILL.md             ← commande de rétrospective
```

Chaque projet (chaque **mission**) a un **module de commande** :

```
<workspace>/
├── CLAUDE.md                  → 🔗 symlink vers le vaisseau-mère
└── .claude/
    ├── agents/                 → 🔗 symlink vers le vaisseau-mère
    ├── skills/                 → 🔗 symlink vers le vaisseau-mère
    ├── 📓 project-context.md   ← LOCAL : registre de mission (stack, conventions)
    └── 📚 feedback/             ← LOCAL : journaux de bord de cette mission
```

---

## 🛸 Embarquement sur un nouveau projet

> ⚠️ **Modèle « workspace de commande »**
> Le dossier où tu poses la passerelle Claude est **un module dédié à la config**. Il ne contient PAS tes 3 repos (iOS, Android, API) — il les **référence** via leurs chemins absolus, déclarés dans `project-context.md`. Tes repos restent à leur orbite habituelle.

### 🚀 Étape 1 — Construis ta passerelle

Choisis un emplacement pour la config Claude. Recommandation : un dossier dédié par projet, séparé de tes repos de code.

```bash
mkdir -p ~/Claude/MyApp
cd ~/Claude/MyApp
```

Tu peux nommer ce dossier comme tu veux (`~/Claude/<nom>`, `~/workspaces/<nom>`, peu importe). Ce sera le **cwd** depuis lequel tu lanceras Claude Code.

### 🔧 Étape 2 — Embarque l'équipage

```bash
bash ~/work/claude-mobile-agents/install.sh
```

Le module d'embarquement :

1. 💾 Sauvegarde les éventuels `CLAUDE.md` / `.claude/agents` / `.claude/skills` existants (suffixe `.backup.YYYYMMDD-HHMMSS`)
2. 🔗 Pose les symlinks vers le vaisseau-mère
3. 📚 Crée `.claude/feedback/` local
4. 📓 Copie le template `project-context.md.template` dans `.claude/project-context.md`
5. 🗺️ **Te demande les coordonnées de tes 3 repos** (mode interactif) — saisie validée à la volée

### 🗺️ Étape 3 — Donne les coordonnées de tes repos

Pendant l'install, le script te demande successivement :

```
  ➤ API  (api-dir)
    Exemple : /Users/nico/Code/MyApp-API
    Chemin absolu : _

  ➤ iOS  (ios-dir)
    ...

  ➤ Android  (android-dir)
    ...
```

🛡️ **Règles de saisie** :
- ✅ **Chemins absolus uniquement** (commencent par `/`). Pas de `./`, pas de `~/` (sauf le tilde qui est étendu automatiquement).
- ✅ Chaque dossier doit exister et **contenir son propre `.git/`** (un avertissement non bloquant sinon).
- ⏭️ **Enter vide** = je n'ai pas ce composant (ex. mission backend-only) → placeholder gardé.
- ✏️ Tu peux corriger plus tard en éditant `.claude/project-context.md` à la main.

### 🎯 Étape 4 — Première mission

```bash
cd ~/Claude/MyApp       # la passerelle, pas un de tes repos
# (lance Claude Code ici — terminal, app desktop, ou web)
/feature "ma première mission"
```

Au premier passage, `project-discoverer` lit tes 3 chemins, va scanner ces dossiers pour extraire la stack (framework API, DS iOS, etc.) et complète `project-context.md`. Tu valides en 2 min, le workflow normal démarre.

### 🌌 Cas particulier — Repos déjà sous un dossier commun

Si tu as déjà une structure du genre :

```
~/Code/MyApp/
├── MyAppAPI/
├── MyAppIOS/
└── MyAppAndroid/
```

Tu peux faire de `~/Code/MyApp/` lui-même la passerelle (lance `install.sh` dedans). Tu déclareras alors les chemins absolus pointant vers ses sous-dossiers (`/Users/.../Code/MyApp/MyAppAPI`, etc.). Pas besoin d'un dossier séparé.

---

## 🛡️ Juridictions (périmètres d'écriture)

Chaque membre d'équipage a son périmètre verrouillé — pas de débordement, pas de catastrophe :

| Agent | Peut écrire dans |
|---|---|
| 🔭 `project-discoverer` | `.claude/project-context.md` uniquement |
| 📋 `feature-planner` | rien (read-only) |
| ⚡ `api-builder` | `<api-dir>/` (lu dans `project-context.md`) |
| 🛡️ `api-reviewer` | rien (read-only) |
| 🍎 `ios-builder` *(V2)* | `<ios-dir>/` |
| 🤖 `android-builder` *(V2)* | `<android-dir>/` |
| 🛡️ `mobile-reviewer` *(V2)* | rien (read-only) |
| 🧠 `system-retrospective` | rien (propose des diffs, c'est `/feature-retro` qui applique) |

🚫 **Aucun agent ne commit automatiquement.** Toujours proposé au capitaine, jamais imposé.

---

## 🧠 Boucle d'apprentissage de l'équipage

L'équipage devient meilleur à chaque mission. C'est conçu pour ça.

1. 📓 Chaque `/feature` se termine par un **journal de bord obligatoire** (5 notes + 2 retours libres)
2. 💾 Le journal est archivé dans `.claude/feedback/<date>-<slug>.md`
3. 🧠 Quand 3+ journaux s'accumulent, lance `/feature-retro`
4. 🔍 Les patterns récurrents (signal ≥ 2 fois) déclenchent des **patches** :
   - 🎯 **Projet** : durcissent `.claude/project-context.md` de cette mission
   - 🌌 **Système** : améliorent l'équipage pour **toutes** les missions futures (avec confirmation supplémentaire)
5. 🛡️ Patches validés un par un → appliqués → optionnellement commit du vaisseau-mère

---

## 🔄 Maintenance du vaisseau

Le vaisseau-mère est versionné. Pour récupérer les améliorations partagées :

```bash
cd ~/work/claude-mobile-agents
git pull
```

✨ Toutes les missions qui pointent vers ce vaisseau via leurs symlinks reçoivent **instantanément** la nouvelle version. Rien à refaire côté projet.

---

## 🧰 Prérequis

- 🤖 **Claude Code** (CLI, app desktop, app web, ou IDE — tous compatibles)
- 📦 **Node ≥ 20** et `npm` (pour `api-builder` qui compile)
- 🌳 **Git** (3 repos git attendus par projet : api, ios, android)
- 🍎 **Xcode** pour les builds iOS *(V2)*
- 🤖 **Gradle / Android Studio** pour les builds Android *(V2)*

---

## 🚦 État de la flotte — V1

✅ **Scope `api` opérationnel** : reconnaissance, planificateur, ingénieur API, inspecteur API, journal de bord, rétrospective.
🚧 **Scope `mobile` et `api+mobile`** : ingénieurs iOS / Android / inspecteur mobile **en squelette**. Le système avertit le capitaine si une mission demande du mobile et propose de soit continuer en mode partiel, soit recentrer la mission sur du backend.

---

## 🛰️ Roadmap V2

- 🍎 Compléter `ios-builder` avec connaissance fine de SwiftUI + adaptation au pattern d'archi du projet
- 🤖 Compléter `android-builder` avec connaissance fine de Compose + parité stricte iOS
- 🛡️ Compléter `mobile-reviewer` avec checklist parité iOS↔Android
- ⚖️ Ajouter un agent `parity-auditor` qui compare les outputs iOS et Android après les builders

---

## 📜 Licence

Privé — usage personnel. *Ad astra.* 🌌
