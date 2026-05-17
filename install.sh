#!/usr/bin/env bash
# Installe le système d'agents claude-mobile-agents dans un projet.
# Usage : depuis la racine de ton projet, lancer :
#   bash ~/work/claude-mobile-agents/install.sh
# ou rendre le script exécutable (`chmod +x install.sh`) et invoquer directement.
set -euo pipefail

# ---------- Configuration ----------
SYSTEM_REPO="${CLAUDE_MOBILE_AGENTS_REPO:-$HOME/work/claude-mobile-agents}"
PROJECT_ROOT="$(pwd)"

# ---------- Vérifications ----------
if [[ ! -d "$SYSTEM_REPO" ]]; then
  echo "❌ Repo système introuvable à $SYSTEM_REPO" >&2
  echo "   Définis la variable CLAUDE_MOBILE_AGENTS_REPO si tu l'as cloné ailleurs." >&2
  exit 1
fi

if [[ ! -f "$SYSTEM_REPO/CLAUDE.md" ]]; then
  echo "❌ $SYSTEM_REPO/CLAUDE.md introuvable — le repo système n'est pas valide." >&2
  exit 1
fi

if [[ ! -d "$SYSTEM_REPO/.claude/agents" ]] || [[ ! -d "$SYSTEM_REPO/.claude/skills" ]]; then
  echo "❌ Structure attendue $SYSTEM_REPO/.claude/{agents,skills} manquante." >&2
  exit 1
fi

echo "📦 Installation du système d'agents dans : $PROJECT_ROOT"
echo "   Source : $SYSTEM_REPO"
echo ""

# ---------- Sauvegarde des fichiers existants ----------
backup_if_exists() {
  local path="$1"
  if [[ -e "$path" && ! -L "$path" ]]; then
    local backup="${path}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "💾 Sauvegarde de $path → $backup"
    mv "$path" "$backup"
  elif [[ -L "$path" ]]; then
    echo "🔗 Symlink existant à $path : suppression (sera recréé)"
    rm "$path"
  fi
}

backup_if_exists "$PROJECT_ROOT/CLAUDE.md"
backup_if_exists "$PROJECT_ROOT/.claude/agents"
backup_if_exists "$PROJECT_ROOT/.claude/skills"

# ---------- Création des dossiers locaux ----------
mkdir -p "$PROJECT_ROOT/.claude/feedback"

# ---------- Pose des symlinks ----------
echo ""
echo "🔗 Pose des symlinks…"
ln -s "$SYSTEM_REPO/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.md"
echo "   CLAUDE.md → $SYSTEM_REPO/CLAUDE.md"

ln -s "$SYSTEM_REPO/.claude/agents" "$PROJECT_ROOT/.claude/agents"
echo "   .claude/agents → $SYSTEM_REPO/.claude/agents"

ln -s "$SYSTEM_REPO/.claude/skills" "$PROJECT_ROOT/.claude/skills"
echo "   .claude/skills → $SYSTEM_REPO/.claude/skills"

# ---------- Initialisation de feedback/ ----------
if [[ ! -f "$PROJECT_ROOT/.claude/feedback/README.md" ]]; then
  cat > "$PROJECT_ROOT/.claude/feedback/README.md" <<'EOF'
# Journaux de feedback `/feature` (local au projet)

Ce dossier contient les journaux générés à la fin de chaque `/feature`.
Chaque journal : 5 notes (1-5) + 2 textes libres + stats git + métadonnées.

Quand 3+ journaux sont accumulés, lance `/feature-retro` pour proposer des
patches d'amélioration. Les patches `projet` modifient `.claude/project-context.md`,
les patches `système` modifient le repo générique partagé (avec confirmation).

Ne pas modifier à la main : ajoute une section `## Note post-hoc` si nécessaire.
EOF
  echo "✅ .claude/feedback/README.md créé"
fi

if [[ ! -f "$PROJECT_ROOT/.claude/feedback/.gitkeep" ]]; then
  touch "$PROJECT_ROOT/.claude/feedback/.gitkeep"
fi

# ---------- Préparation du project-context.md ----------
CONTEXT_FILE="$PROJECT_ROOT/.claude/project-context.md"

echo ""
if [[ -f "$CONTEXT_FILE" ]]; then
  echo "ℹ️  .claude/project-context.md existe déjà — pas de réécriture."
  echo "   Vérifie que la section 'Chemins' contient bien tes 3 chemins absolus."
  SKIP_PATH_PROMPTS=1
else
  cp "$SYSTEM_REPO/templates/project-context.md.template" "$CONTEXT_FILE"
  echo "✅ .claude/project-context.md créé depuis le template"
  SKIP_PATH_PROMPTS=0
fi

# ---------- Saisie interactive des chemins absolus ----------
# Fonction qui demande un chemin absolu, valide, et écrit le résultat sur stdout.
# Tous les messages utilisateur partent sur stderr pour ne pas polluer la capture.
read_abs_path() {
  local label="$1"      # ex. "API"
  local key="$2"        # ex. "api-dir"
  local example="$3"
  local path=""

  while true; do
    {
      echo ""
      echo "  ➤ $label  ($key)"
      echo "    Exemple : $example"
      echo "    (Enter pour skipper — utile si ton projet n'a pas ce composant)"
    } >&2
    printf "    Chemin absolu : " >&2
    if ! IFS= read -r path; then
      # stdin fermé ou non-TTY → on skip silencieusement
      echo "" >&2
      return 0
    fi

    # Skip explicite (vide)
    if [[ -z "$path" ]]; then
      echo "    ⏭️  $label skippé (le placeholder reste dans project-context.md, à compléter à la main si besoin)" >&2
      return 0
    fi

    # Expansion de ~
    path="${path/#\~/$HOME}"

    # Doit être absolu
    if [[ "$path" != /* ]]; then
      echo "    ❌ Le chemin doit être absolu (commencer par /). Réessaie ou Enter pour skipper." >&2
      continue
    fi

    # Doit exister
    if [[ ! -d "$path" ]]; then
      echo "    ❌ Dossier introuvable : $path" >&2
      printf "    Continuer quand même ? (o/N) : " >&2
      local confirm=""
      IFS= read -r confirm || confirm=""
      if [[ "$confirm" != "o" && "$confirm" != "O" ]]; then
        continue
      fi
    fi

    # Idéalement repo git
    if [[ -d "$path" ]] && [[ ! -d "$path/.git" ]]; then
      echo "    ⚠️  $path n'a pas de .git/ — les builders/reviewers n'auront pas de diff git." >&2
      printf "    Continuer ? (O/n) : " >&2
      local confirm=""
      IFS= read -r confirm || confirm=""
      if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        continue
      fi
    fi

    echo "    ✅ $label = $path" >&2
    printf '%s' "$path"
    return 0
  done
}

# sed portable BSD/GNU pour macOS et Linux.
update_yaml_line() {
  local key="$1"
  local value="$2"
  local file="$3"

  if [[ -z "$value" ]]; then
    return 0   # rien à écrire, on garde le placeholder
  fi

  # délimiteur | pour éviter les conflits avec les / des chemins
  if sed --version >/dev/null 2>&1; then
    # GNU sed (Linux)
    sed -i "s|^${key}: .*|${key}: ${value}|" "$file"
  else
    # BSD sed (macOS)
    sed -i '' "s|^${key}: .*|${key}: ${value}|" "$file"
  fi
}

API_DIR=""
IOS_DIR=""
ANDROID_DIR=""

if [[ "$SKIP_PATH_PROMPTS" -eq 0 ]]; then
  echo ""
  echo "════════════════════════════════════════════════════════════════════════════"
  echo "📁 Déclare les chemins absolus de tes 3 repos"
  echo "════════════════════════════════════════════════════════════════════════════"
  echo "Ces 3 repos peuvent vivre n'importe où sur le disque. Tu peux skipper avec"
  echo "Enter si un composant n'existe pas pour ce projet (par ex. backend-only)."
  echo ""

  if [[ -t 0 ]]; then
    API_DIR=$(read_abs_path "API"     "api-dir"     "/Users/nico/Code/MyApp-API")
    IOS_DIR=$(read_abs_path "iOS"     "ios-dir"     "/Users/nico/Sources/MyApp-iOS")
    ANDROID_DIR=$(read_abs_path "Android" "android-dir" "/Users/nico/Dev/MyApp-Android")

    update_yaml_line "api-dir"     "$API_DIR"     "$CONTEXT_FILE"
    update_yaml_line "ios-dir"     "$IOS_DIR"     "$CONTEXT_FILE"
    update_yaml_line "android-dir" "$ANDROID_DIR" "$CONTEXT_FILE"

    echo ""
    echo "✅ Chemins écrits dans $CONTEXT_FILE"
  else
    echo "⚠️  stdin n'est pas un TTY — saisie interactive sautée."
    echo "   Ouvre $CONTEXT_FILE et complète la section 'Chemins' à la main."
  fi
fi

# ---------- Vérifications finales ----------
echo ""
echo "🔍 Vérifications finales :"
for f in "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/.claude/agents" "$PROJECT_ROOT/.claude/skills"; do
  if [[ -L "$f" ]] && [[ -e "$f" ]]; then
    echo "   ✅ $f"
  else
    echo "   ❌ $f (symlink cassé ou manquant)" >&2
    exit 1
  fi
done

echo ""
echo "🎉 Installation terminée."
echo ""

# Récap des chemins renseignés
ALL_FILLED=1
echo "📁 Chemins déclarés dans $CONTEXT_FILE :"
if [[ -n "$API_DIR" ]];     then echo "   API     : $API_DIR";     else echo "   API     : (non renseigné — placeholder à compléter à la main)"; ALL_FILLED=0; fi
if [[ -n "$IOS_DIR" ]];     then echo "   iOS     : $IOS_DIR";     else echo "   iOS     : (non renseigné — placeholder à compléter à la main)"; ALL_FILLED=0; fi
if [[ -n "$ANDROID_DIR" ]]; then echo "   Android : $ANDROID_DIR"; else echo "   Android : (non renseigné — placeholder à compléter à la main)"; ALL_FILLED=0; fi
echo ""

if [[ "$ALL_FILLED" -eq 0 && "$SKIP_PATH_PROMPTS" -eq 0 ]]; then
  echo "⚠️  Certains chemins sont vides. Le scope correspondant (mobile / api+mobile)"
  echo "    sera refusé par /feature tant que tu n'as pas complété $CONTEXT_FILE."
  echo ""
fi

echo "Pour lancer ta première feature, dans Claude Code à la racine de :"
echo "  $PROJECT_ROOT"
echo "Lance :"
echo "  /feature <description de ta première feature>"
echo ""
echo "Le workflow : project-discoverer (complète project-context.md à partir des chemins)"
echo "→ planner → gate humaine → build → review → feedback obligatoire."
echo ""
echo "Système versionné dans : $SYSTEM_REPO"
echo "Pour mettre à jour le système : cd $SYSTEM_REPO && git pull"
