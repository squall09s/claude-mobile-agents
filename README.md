# 🛸 claude-mobile-agents

Une flotte d'agents Claude Code spécialisés pour livrer des features de bout en bout sur des projets **mobile natif + API Node/TS**. L'équipage exécute, le développeur pilote.

Conçu pour des projets qui suivent ce schéma :

- **iOS natif** (SwiftUI) — repo dédié
- **Android natif** (Jetpack Compose) — repo dédié
- **API Node + TypeScript** (Express 5 / Fastify / NestJS) — repo dédié
- DB libre (MongoDB, PostgreSQL, Supabase, autre), auth JWT
- Design system maison répliqué iOS/Android, parité stricte

---

## 🧑‍🚀 L'équipage

Deux commandes accessibles depuis la passerelle (Claude Code).

### `/feature "<description>"` — lancer une mission

L'équipage prend en charge la feature de bout en bout :

1. **Reconnaissance** au premier passage sur un projet — `project-discoverer` lit les chemins absolus déclarés puis complète `.claude/project-context.md` à partir du code scanné
2. **Briefing** par `feature-planner` (détermine le scope : `api` / `mobile` / `api+mobile`)
3. **Validation humaine** sur le plan (`go` / `revoir` / `stop`)
4. **Construction** selon scope :
   - `api` → `api-builder` puis `api-reviewer`
   - `mobile` → `ios-builder` et `android-builder` en parallèle, puis `mobile-reviewer` *(V2)*
   - `api+mobile` → API d'abord, mobile ensuite *(V2 côté mobile)*
5. **Compte-rendu** au développeur (fichiers touchés, tests, verdict review)
6. **Proposition de commit** par sous-projet — jamais automatique
7. **Journal de bord obligatoire** : 5 notes + 2 retours libres, archivé dans `.claude/feedback/`

### `/feature-retro` — faire évoluer l'équipage

L'équipage apprend de ses missions. À partir de 3 journaux de bord accumulés, la rétrospective tourne :

1. **Analyse** par `system-retrospective` — lecture des journaux non archivés
2. **Améliorations proposées** sous forme de diff, classées `projet` (locales à la mission courante) ou `système` (impactent toute la flotte)
3. **Validation patch par patch** (`apply` / `skip` / `edit` / `stop`)
4. **Application** des patches retenus
5. **Commit optionnel** du repo système si des patches `système` ont été appliqués
6. **Archivage** des journaux exploités

---

## 🛰️ Architecture

Le vaisseau-mère (versionné, partagé entre tous les projets) :

```
~/work/claude-mobile-agents/
├── README.md
├── install.sh                            ← module d'embarquement
├── CLAUDE.md                             ← philosophie générique
├── templates/
│   └── project-context.md.template       ← gabarit du registre de mission
└── .claude/
    ├── agents/
    │   ├── project-discoverer.md         ← scout : complète project-context.md
    │   ├── feature-planner.md            ← stratège : plan + scope
    │   ├── api-builder.md                ← ingénieur API (Node+TS multi-framework)
    │   ├── api-reviewer.md               ← inspecteur API (review via git diff)
    │   ├── ios-builder.md                ← ingénieur iOS (V2 — squelette)
    │   ├── android-builder.md            ← ingénieur Android (V2 — squelette)
    │   ├── mobile-reviewer.md            ← inspecteur mobile (V2 — squelette)
    │   └── system-retrospective.md       ← analyste : propose des améliorations
    └── skills/
        ├── feature/SKILL.md
        └── feature-retro/SKILL.md
```

Chaque projet (chaque mission) dispose d'une passerelle de commande locale :

```
<workspace>/
├── CLAUDE.md                  → symlink vers le vaisseau-mère
└── .claude/
    ├── agents/                → symlink vers le vaisseau-mère
    ├── skills/                → symlink vers le vaisseau-mère
    ├── project-context.md     ← local : registre de mission (stack, conventions)
    └── feedback/              ← local : journaux de bord de la mission
```

---

## 🚀 Embarquement sur un nouveau projet

> **Modèle « workspace de commande ».**
> Le dossier où vit la passerelle Claude est un module dédié à la config. Il **ne contient pas** les trois repos (iOS, Android, API) — il les **référence** via leurs chemins absolus déclarés dans `project-context.md`. Les repos restent à leur orbite habituelle.

### Étape 1 — Préparer la passerelle

Choisir un emplacement pour la config Claude, séparé des repos de code. Recommandation : un dossier dédié par projet.

```bash
mkdir -p ~/Claude/MyApp
cd ~/Claude/MyApp
```

Le nom du dossier est libre (`~/Claude/<nom>`, `~/workspaces/<nom>`, etc.). C'est le **cwd** depuis lequel Claude Code sera lancé.

### Étape 2 — Embarquer l'équipage

```bash
bash ~/work/claude-mobile-agents/install.sh
```

Le module d'embarquement effectue :

1. Sauvegarde des éventuels `CLAUDE.md` / `.claude/agents` / `.claude/skills` existants (suffixe `.backup.YYYYMMDD-HHMMSS`)
2. Pose des symlinks vers le vaisseau-mère
3. Création de `.claude/feedback/` local
4. Copie du template `project-context.md.template` vers `.claude/project-context.md`
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
- **Enter vide** = composant absent (ex. mission backend-only) → placeholder conservé.
- Modification possible plus tard en éditant `.claude/project-context.md` à la main.

### Étape 4 — Première mission

```bash
cd ~/Claude/MyApp       # la passerelle, pas un repo de code
# (lancer Claude Code ici — terminal, app desktop, ou web)
/feature "première mission"
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

`~/Code/MyApp/` peut servir directement de passerelle (lancer `install.sh` dedans). Les chemins absolus pointeront vers ses sous-dossiers (`/Users/.../Code/MyApp/MyAppAPI`, etc.).

---

## 🛡️ Juridictions (périmètres d'écriture)

Chaque membre d'équipage opère dans un périmètre verrouillé.

| Agent | Périmètre d'écriture |
|---|---|
| `project-discoverer` | `.claude/project-context.md` uniquement |
| `feature-planner` | rien (read-only) |
| `api-builder` | `<api-dir>/` (lu dans `project-context.md`) |
| `api-reviewer` | rien (read-only) |
| `ios-builder` *(V2)* | `<ios-dir>/` |
| `android-builder` *(V2)* | `<android-dir>/` |
| `mobile-reviewer` *(V2)* | rien (read-only) |
| `system-retrospective` | rien (propose des diffs, `/feature-retro` applique) |

**Aucun agent ne commit automatiquement.** Tout commit est proposé au développeur, jamais imposé.

---

## 🧠 Boucle d'apprentissage

L'équipage devient meilleur à chaque mission — c'est conçu pour ça.

1. Chaque `/feature` se termine par un journal de bord obligatoire (5 notes + 2 retours libres)
2. Le journal est archivé dans `.claude/feedback/<date>-<slug>.md`
3. Quand 3 journaux ou plus s'accumulent, le déclenchement de `/feature-retro` devient pertinent
4. Les patterns récurrents (signal présent au moins deux fois) déclenchent des patches :
   - **Projet** : durcissent `.claude/project-context.md` de la mission courante
   - **Système** : améliorent l'équipage pour toutes les missions futures (confirmation supplémentaire requise)
5. Patches validés un par un → appliqués → commit optionnel du vaisseau-mère

---

## 🔄 Maintenance du vaisseau

Le vaisseau-mère est versionné. Pour intégrer les améliorations partagées :

```bash
cd ~/work/claude-mobile-agents
git pull
```

Toutes les missions qui pointent vers ce vaisseau via leurs symlinks reçoivent instantanément la nouvelle version. Aucune action requise côté projet.

---

## 🧰 Prérequis

- **Claude Code** (CLI, app desktop, app web, ou IDE — tous compatibles)
- **Node ≥ 20** et `npm` (pour `api-builder` qui compile)
- **Git** (trois repos git attendus par projet : api, ios, android)
- **Xcode** pour les builds iOS *(V2)*
- **Gradle / Android Studio** pour les builds Android *(V2)*

---

## État de la flotte — V1

✅ **Scope `api` opérationnel** : reconnaissance, planificateur, ingénieur API, inspecteur API, journal de bord, rétrospective.

🚧 **Scope `mobile` et `api+mobile`** : ingénieurs iOS / Android et inspecteur mobile en **squelette**. Le système avertit le développeur lorsqu'une mission demande du mobile et propose soit de continuer en mode partiel, soit de recentrer la mission sur du backend.

---

## Roadmap V2

- Compléter `ios-builder` avec connaissance fine de SwiftUI et adaptation au pattern d'archi du projet
- Compléter `android-builder` avec connaissance fine de Compose et parité stricte iOS
- Compléter `mobile-reviewer` avec checklist parité iOS ↔ Android
- Ajouter un agent `parity-auditor` qui compare les sorties iOS et Android après les builders

---

## Licence

Privé — usage personnel. *Ad astra.*
