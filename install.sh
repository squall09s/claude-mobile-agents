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

# ---------- Détection projet-context ----------
echo ""
if [[ -f "$PROJECT_ROOT/.claude/project-context.md" ]]; then
  echo "ℹ️  .claude/project-context.md existe déjà — pas de regénération automatique."
  echo "   Si tu veux une re-discovery, supprime-le ou édite-le à la main."
else
  echo "ℹ️  .claude/project-context.md n'existe pas — il sera généré automatiquement"
  echo "   par l'agent project-discoverer au premier /feature."
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
echo "Prochaines étapes :"
echo "  1. Ouvre Claude Code à la racine du projet ($PROJECT_ROOT)"
echo "  2. Lance \`/feature <description de ta première feature>\`"
echo "  3. Au premier lancement, project-discoverer va scanner le projet"
echo "     et générer .claude/project-context.md (à valider en 2 min)"
echo "  4. Le workflow normal s'enchaîne ensuite (plan → gate → build → review → feedback)"
echo ""
echo "Système versionné dans : $SYSTEM_REPO"
echo "Pour mettre à jour le système : cd $SYSTEM_REPO && git pull"
