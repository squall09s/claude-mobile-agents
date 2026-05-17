---
name: ds-audit
description: Lance un audit complet du design system maison du projet courant (côté iOS et Android). Détecte bypass d'usage, doublons de composants, divergences de cohérence iOS↔Android, et suggère des évolutions. Read-only — produit un rapport, ne modifie rien. À utiliser périodiquement (chaque mois, ou après une période d'ajout intensif d'écrans) pour maintenir la santé du DS.
---

# Skill `/ds-audit` — audit complet du design system

Le développeur a invoqué `/ds-audit`. Tu orchestres `ds-guardian` en mode `full` pour produire un audit complet du DS du projet courant, et tu présentes le rapport.

## Pré-vol

1. **Identifie le project root** : `pwd` doit être à la racine d'un projet avec `CLAUDE.md` (symlink) et `.claude/project-context.md`.
2. **Vérifie les pré-requis** :
   - `.claude/project-context.md` existe et a `ios-dir` + `android-dir` renseignés
   - Les deux dossiers existent et contiennent du code

Si l'un des deux manque (projet backend-only par exemple) → annonce : « Ce projet n'a pas de stack mobile complète (`ios-dir` ou `android-dir` manquant). L'audit DS n'a pas de sens ici. »

## Étape 1 — Lancer ds-guardian en mode full

Lance l'agent `ds-guardian` avec :

- **Contexte** : « Mode `full`. Audite le design system complet du projet : (1) bypass d'usage sur tous les écrans iOS et Android, (2) doublons et orphelins dans le DS, (3) cohérence fine iOS↔Android des composants existants dans les deux plateformes, (4) suggestions d'évolution (nouveaux composants, nouvelles entrées de thème) basées sur les patterns récurrents observés. Read-only. »

L'audit peut prendre du temps (5-15 min selon la taille du projet) car il lit l'intégralité du code UI des deux plateformes.

## Étape 2 — Présenter le rapport

Affiche **l'intégralité du rapport** produit par ds-guardian. C'est dense — c'est voulu, c'est l'intérêt d'un audit standalone par rapport au mode scoped dans `/feature`.

## Étape 3 — Synthèse pour le développeur

Sous le rapport complet, ajoute une synthèse actionnable en quelques puces :

```
# Synthèse — que faire maintenant ?

## Priorités identifiées
1. **Bypass urgent** : <n> bypass sur les écrans (impact UX). À nettoyer via une feature `mobile` ciblée.
2. **Doublons à fusionner** : <n> doublons détectés. À traiter par une feature de refacto DS dédiée.
3. **Divergences accidentelles** : <n> divergences iOS↔Android sans raison documentée. À aligner.

## Features suggérées (par effort croissant)
- **Petite** : « remplacer les couleurs hardcodées par `<Prefix>Theme.colors` dans les écrans Pro » (~10 fichiers iOS + 10 Android)
- **Moyenne** : « unifier les variantes `<Prefix>Button*` en un seul composant paramétré » (refacto + migration des écrans qui les utilisent)
- **Grosse** : « créer le composant `<Prefix>ListRow` et migrer les 10+ écrans qui implémentent ce pattern à la main »

## Pas d'action
Si le rapport indique « PASS » sans suggestion, c'est que le DS est sain. Bravo.
```

## Étape 4 — Proposition de lancer une feature de refacto

Termine en demandant :

> Tu veux lancer immédiatement une feature de refacto pour traiter l'une des priorités ?
> - **« feature: <description> »** : je transfère vers `/feature` avec la description
> - **« note »** : je note les follow-ups dans un fichier pour plus tard (à toi de décider quand les lancer)
> - **« stop »** : aucune action, le rapport est juste pour info

### Si « note »

Écris un fichier `.claude/ds-followups.md` (créé s'il n'existe pas, sinon append) avec :

```markdown
## <YYYY-MM-DD> — Audit DS

(extrait synthèse des priorités du rapport)

À traiter :
- [ ] Bypass à nettoyer dans les écrans Pro (priorité haute)
- [ ] Unifier les variantes <Prefix>Button*
- [ ] Créer <Prefix>ListRow
```

Annonce : « Follow-ups notés dans `.claude/ds-followups.md`. Tu peux les consulter à tout moment ou lancer `/ds-audit` à nouveau plus tard pour mesurer les progrès. »

### Si « feature: <description> »

Annonce : « Je délègue à `/feature` avec ta description. La feature suivra le workflow normal (plan + gate humaine + builders + reviewers + parity-auditor + ds-guardian scoped + context-keeper + feedback). »

(Le dev doit ensuite lancer `/feature "<description>"` lui-même — tu ne peux pas l'invoquer en cascade depuis ce skill.)

## Règles d'orchestration

- **Pas d'application automatique** des refactos. ds-guardian propose, le dev décide. C'est ce qui rend l'audit safe.
- **Mode full systématique** ici (par opposition au mode scoped dans `/feature`). C'est ce qui justifie d'avoir une commande standalone.
- **Pas de capture de feedback** à la fin (différent de `/feature`). C'est un audit consultatif, pas une action. Si l'audit aboutit à une feature de refacto, c'est cette feature qui aura son journal de feedback habituel.
- **Pas de gate** sur le rapport — c'est consultatif. La seule gate est sur le choix final (note / feature / stop).

## Cas particulier — projet sans DS maison

Si `ds-guardian` détecte qu'il n'y a pas de DS maison (pas de dossier `UI/DesignSystem/` ni `ui/designsystem/`, pas de préfixe identifiable dans `project-context.md`), il s'arrête et te signale. Annonce alors au développeur :

> Ce projet ne semble pas avoir de DS maison. L'audit DS n'a pas d'objet. Si tu veux en mettre un en place, lance plutôt :
> `/feature "mettre en place un design system maison avec <Prefix>Theme, <Prefix>PrimaryButton, ..."`

## Erreurs courantes à éviter

- Lancer une refacto automatique depuis ce skill (jamais)
- Capture de feedback à la fin (pas adapté ici)
- Audit en mode scoped depuis `/ds-audit` (ça doit toujours être full ici, le scoped est réservé au `/feature`)
- Ignorer le rapport sous prétexte qu'il est long — c'est le but
