---
title: Restructuration des workspaces sand avec config TOML
type: feat
date: 2026-02-18
---

# Restructuration des workspaces sand avec config TOML

## Overview

Remplacer le format texte plat des workspaces (`nom chemin` par ligne) par des fichiers TOML riches permettant de personnaliser le layout, les tabs, les panels et les apps TUI de chaque workspace. Ajouter un wizard interactif `sand workspace new` et un catalogue d'apps TUI.

## Problem Statement

Le système de workspaces actuel est sous-exploité :
- Format texte plat sans structure (`~/.config/sand/workspaces/diderot` = 2 lignes)
- Layout identique pour tous les tabs (lazygit + yazi en dur)
- Aucune personnalisation des apps ou de l'arrangement des panels
- Pas de commande pour créer/gérer les workspaces
- Un seul workspace existant (`diderot`)

## Proposed Solution

### Format TOML par workspace

Chaque workspace devient un fichier `.toml` dans `~/.config/sand/workspaces/` :

```toml
[workspace]
name = "diderot"
description = "Client Diderot — netcampus + dec"
root = "~/Dev/clients/diderot"     # optionnel, base pour chemins relatifs

[[tabs]]
name = "netcampus"
dir = "netcampus"                   # relatif à root
layout = "default"                  # preset: default, wide, solo, monitoring

[[tabs.panels]]
app = "lazygit"

[[tabs.panels]]
app = "yazi"

[[tabs]]
name = "dec"
dir = "dec"
layout = "default"

# panels omis → utilise les panels par défaut du layout
```

### Layouts presets

Plutôt que de demander aux utilisateurs de définir des splits imbriqués, on propose des **presets de layout** qui organisent les panels dans des slots prédéfinis :

```
"default" (actuel)                    "wide"
┌───────────────┬──────────┐          ┌──────────────────────────┐
│               │ panel-1  │          │        terminal          │
│   terminal    │          │          │                          │
│   principal   ├──────────┤          ├─────────┬────────┬───────┤
│               │ panel-2  │          │ panel-1 │ panel-2│panel-3│
├───────┬───────┤          │          └─────────┴────────┴───────┘
│term-2 │term-3 │          │
└───────┴───────┴──────────┘

"solo"                                "monitoring"
┌──────────────────────────┐          ┌───────────────┬──────────┐
│                          │          │               │ panel-1  │
│         terminal         │          │   terminal    ├──────────┤
│                          │          │   principal   │ panel-2  │
│                          │          │               ├──────────┤
└──────────────────────────┘          │               │ panel-3  │
                                      └───────────────┴──────────┘
```

Chaque preset a des **slots panel** prédéfinis. Si l'utilisateur définit des panels, ils remplissent les slots dans l'ordre. Si non, les panels par défaut du preset s'appliquent (lazygit + yazi pour `default`).

### Catalogue d'apps TUI

Catalogue intégré au script avec détection d'installation :

| App | Commande | Catégorie | Taille défaut |
|-----|----------|-----------|---------------|
| lazygit | `lazygit` | git | 50% |
| yazi | `yazi .` | fichiers | 50% |
| btop | `btop` | monitoring | 50% |
| lazydocker | `lazydocker` | docker | 50% |
| serpl | `serpl` | search/replace | 50% |
| bacon | `bacon` | watch (rust) | 30% |
| watchexec | `watchexec -- make` | watch (generic) | 30% |
| lnav | `lnav` | logs | 50% |
| posting | `posting` | http | 50% |
| k9s | `k9s` | kubernetes | 50% |
| pgcli | `pgcli` | database | 50% |
| gitui | `gitui` | git | 50% |
| broot | `broot` | fichiers | 50% |
| shell | _(terminal vide)_ | - | 50% |

L'utilisateur peut aussi mettre une commande custom :
```toml
[[tabs.panels]]
command = "docker compose logs -f"
```

### Sous-commandes workspace

```
sand workspace new              Wizard interactif
sand workspace list             Lister les workspaces
sand workspace edit <nom>       Ouvrir le TOML dans $EDITOR
sand workspace show <nom>       Afficher le contenu formaté
sand workspace delete <nom>     Supprimer un workspace
sand workspace migrate          Migrer les anciens fichiers texte → TOML
```

### Wizard interactif (`sand workspace new`)

Étapes du wizard (utilise fzf quand disponible, fallback texte) :

1. **Nom** — saisie libre
2. **Description** — saisie libre (optionnel, Entrée pour skip)
3. **Répertoire racine** — saisie ou sélection avec fzf
4. **Tabs** — boucle :
   - Nom du tab
   - Répertoire (relatif à root ou absolu)
   - Layout preset (default/wide/solo/monitoring)
   - Apps de panel (multi-sélection fzf sur le catalogue, filtrée par apps installées)
   - "Ajouter un autre tab ?" → boucle ou fin
5. **Résumé** — affichage formaté du TOML généré
6. **Confirmation** — écriture du fichier

## Technical Considerations

### Parsing TOML en bash

Python est déjà une dépendance (sand-synth). Utiliser un helper Python léger pour parser le TOML et générer le KDL :

```
bin/sand-workspace-helper    # Script Python, appelé par bin/sand
```

Le script principal `bin/sand` reste en bash mais délègue le parsing TOML et la génération KDL au helper Python. Cela évite d'ajouter `tomlq` ou un parser TOML bash fragile.

**Flux** : `sand diderot` → bash détecte le `.toml` → appelle `sand-workspace-helper render diderot.toml` → récupère le KDL sur stdout → passe à Zellij.

### Migration

- Détection : si `<nom>.toml` existe → nouveau format ; si `<nom>` sans extension → ancien format
- Si les deux existent → priorité au `.toml`, warning
- `sand workspace migrate` : lit l'ancien format, génère le TOML avec layout=default et panels par défaut (lazygit + yazi), backup l'ancien en `.bak`
- Migration automatique à la première invocation d'un ancien workspace (avec message)

### Backend tmux (fallback)

Pour la v1 : le TOML génère du KDL (Zellij). En mode tmux, on génère les commandes tmux équivalentes avec une version simplifiée (terminal principal + un seul panel par tab). Le support complet tmux est reporté.

### Gestion des erreurs

- **Répertoire inexistant** : warning + skip du tab (comme actuellement)
- **App non installée** : remplacement par un shell vide avec message `echo "App non trouvée : lazydocker — brew install lazydocker"`
- **TOML invalide** : erreur avec numéro de ligne et explication

## Acceptance Criteria

- [x] `sand workspace new` lance un wizard et crée un fichier `.toml` valide
- [x] `sand diderot` fonctionne avec le nouveau format TOML (migration auto de l'existant)
- [x] `sand workspace list` affiche les workspaces avec nom, description, nombre de tabs
- [x] `sand workspace edit <nom>` ouvre le TOML dans `$EDITOR`
- [x] `sand workspace show <nom>` affiche un résumé formaté
- [x] `sand workspace delete <nom>` supprime avec confirmation
- [x] `sand workspace migrate` convertit les anciens fichiers texte en TOML
- [x] Les 4 layouts presets génèrent du KDL valide
- [x] Le catalogue d'apps est affiché dans le wizard avec détection d'installation
- [x] Les panels custom (`command = "..."`) fonctionnent
- [x] Le fallback tmux produit un layout fonctionnel (simplifié)
- [x] Le workspace `diderot` migré produit exactement le même layout qu'avant

## Fichiers impactés

### Nouveaux
```
bin/sand-workspace-helper     # Helper Python : parsing TOML, génération KDL, wizard backend
```

### Modifiés
```
bin/sand                      # Ajout sous-commande workspace, appel du helper Python
```

### Supprimés (après migration)
```
~/.config/sand/workspaces/diderot    # Remplacé par diderot.toml
```

## Implementation Phases

### Phase 1 — Helper Python + parsing TOML (fondation)

Créer `bin/sand-workspace-helper` avec :
- `render <fichier.toml>` → génère le KDL sur stdout
- `validate <fichier.toml>` → vérifie la syntaxe et les chemins
- `migrate <fichier_ancien>` → convertit texte → TOML sur stdout
- `catalog` → liste les apps du catalogue avec statut d'installation

Inclut le catalogue d'apps et les templates de layout presets.

**Vérification** : `sand-workspace-helper render diderot.toml` produit un KDL identique au layout généré actuellement par `bin/sand` pour le workspace diderot.

### Phase 2 — Intégration dans bin/sand

Modifier `bin/sand` pour :
- Détecter `.toml` vs ancien format dans `~/.config/sand/workspaces/`
- Appeler `sand-workspace-helper render` pour générer le KDL
- Migration automatique au premier lancement d'un ancien workspace
- Ajout de la sous-commande `workspace` (list, edit, show, delete, migrate)

**Vérification** : `sand diderot` fonctionne comme avant après migration automatique.

### Phase 3 — Wizard interactif

Ajouter `sand workspace new` :
- Wizard pas-à-pas avec fzf (fallback texte)
- Sélection des apps depuis le catalogue (filtre par installées)
- Génération du TOML et confirmation
- Écriture dans `~/.config/sand/workspaces/<nom>.toml`

**Vérification** : créer un workspace de test, le lancer, vérifier que le layout correspond aux choix.

## Dependencies & Risks

- **Python `tomllib`** : disponible depuis Python 3.11 (on a 3.14). Pour l'écriture TOML, utiliser `tomli_w` ou génération manuelle (le format est simple).
- **Risque de régression** : `sand diderot` doit continuer à fonctionner pendant et après la migration. Tests manuels critiques.
- **fzf optionnel** : le wizard doit fonctionner sans fzf (fallback numérique), comme le fait déjà le reste du script.

## References

- Format actuel du workspace : `~/.config/sand/workspaces/diderot`
- Logique de génération KDL : `bin/sand` lignes 107-156
- Layout Zellij par défaut : `layouts/sand.kdl`
- Spécification TOML : https://toml.io/
- Apps TUI recommandées : voir la recherche dans ce plan
