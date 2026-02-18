---
title: "Sons de notification basés sur la psychoacoustique"
type: feat
date: 2026-02-18
---

# Sons de notification basés sur la psychoacoustique

## Overview

Remplacer les sons génériques de `sand-notify` par des sons conçus à partir de la recherche en psychoacoustique. Le projet comprend trois livrables : un document de référence réutilisable, un outil de synthèse (`sand-synth`), et un nouveau pack de sons "zen" optimisé pour une écoute répétitive (50-200 fois/jour).

## Motivation

Les packs actuels (`prout`, `warcraft`, `kaamelott`, `homer`, `inconnus`) sont humoristiques. Le pack `serieux` est fonctionnel mais générique. Aucun pack n'est conçu à partir de données psychoacoustiques pour minimiser le stress et maximiser le confort en écoute répétitive intensive — ce qui est le cas d'un développeur utilisant Claude Code quotidiennement.

## Recherche : synthèse des résultats

### Fréquences et perception

| Plage | Perception | Usage |
|-------|-----------|-------|
| 200-400 Hz | Chaud, enveloppant | Base/fondamentale pour sons de complétion |
| 400-800 Hz | Naturel, agréable | Zone idéale pour notifications non-intrusives |
| 600-2000 Hz | Clair sans agressivité | Recommandation Microsoft pour sons système |
| 800-1500 Hz | Clair, capte l'attention | Sons d'attention douce |
| > 2000 Hz | Perçant, fatiguant | À éviter absolument pour le répétitif |

### Intervalles musicaux et consonance

| Intervalle | Rapport | Usage recommandé |
|-----------|---------|-----------------|
| Quinte juste | 3:2 | "Task complete" — résolution, satisfaction |
| Quarte juste | 4:3 | "Question" — tension légère, invite à l'action |
| Tierce majeure | 5:4 | Satisfaction, chaleur |
| Seconde majeure | 9:8 | Légère tension, interrogation |

**Constat neuroscientifique** : les potentiels évoqués auditifs sont maximaux pour des tons séparés d'une quinte juste (ratio 3:2) — preuve électrophysiologique de la préférence universelle pour les rapports simples.

### Fréquences spécifiques étudiées

- **528 Hz** : étude japonaise (2018) — réduction significative des marqueurs de stress après 5 min d'écoute. Résultats préliminaires mais prometteurs.
- **432 Hz vs 440 Hz** : étude pilote en double aveugle — 432 Hz associé à une diminution du rythme cardiaque (-4,79 bpm). Effet physiologique mesurable mais modeste.
- **Fréquences solfège** : la plupart (174, 285, 396 Hz, etc.) n'ont pas d'études contrôlées. Seul 528 Hz a un socle scientifique partiel.

### Paramètres pour sons répétitifs (50-200x/jour)

Les directives convergentes (Apple, Google Material, Microsoft, études académiques) :

**Durée** :
- Micro-interaction : 50-100 ms
- Notification standard : 200-400 ms
- Complétion de tâche : 300-500 ms
- Maximum pour répétitif fréquent : < 300 ms

**Enveloppe (ADSR)** :
- Attaque : 5-20 ms (rapide mais pas abrupte)
- Decay : 50-200 ms
- Sustain : minimal ou absent
- Release : 100-300 ms (fondu doux, jamais de coupure)

**Contenu harmonique** :
- ~70% harmoniques paires (chaleur, rondeur)
- ~30% harmoniques impaires (brillance modérée)
- Sinusoïdes pures = froid, à éviter seules
- Sons trop riches = fatiguants en répétition

**Test critique** : écouter le son 200 fois d'affilée. S'il agace, il est trop complexe.

### Design des deux sons cibles

#### Son "Stop" (tâche terminée)

Objectif : complétion, satisfaction, retour doux de l'attention.

```
Contour : ascendant (2-3 notes montantes)
          Association universelle ascendant = positif (dès l'âge de 7 mois)
Fondamentale : 440-523 Hz (A4-C5)
Intervalle : quinte juste ascendante (3:2)
Durée : 250-350 ms
Attaque : 10-15 ms
Release : 150-200 ms (fondu doux)
Timbre : marimba/kalimba (harmoniques paires dominantes)
Volume : -6 dB sous le niveau système
```

#### Son "Question" (attention requise)

Objectif : enquête douce, pas d'urgence, invitation à agir.

```
Contour : ascendant interrogatif (montée ouverte, non résolue)
          Imite l'intonation naturelle d'une question
Fondamentale : 500-659 Hz (B4-E5)
Intervalle : quarte juste ascendante (4:3)
Durée : 200-300 ms
Attaque : 15-25 ms
Release : 100-150 ms (fin "ouverte")
Timbre : clochette/celesta (clair, cristallin)
Volume : -3 dB sous le système (légèrement plus présent)
```

### Sources principales

- Microsoft Win32 UX Guidelines — Sound: 600-2000 Hz, < 1s, bords doux
- Google Material Design — Conor O'Sullivan: "concevoir un son qu'on remarque à peine"
- Apple HIG — Playing Audio: sons courts, mélange avec autres sources
- PMC — Neural Correlates of Consonance: preuve EEG quinte juste
- PMC — Ascending Tones and Positive Affect: contour ascendant = positif
- PubMed — 432Hz vs 440Hz Pilot Study: relaxation physiologique
- ResearchGate — 528Hz Study: réduction marqueurs de stress
- Jim Reekes (designer sonore Apple): philosophie sons Mac
- Slack Design — Notification Principles
- Sound Advice (Toptal) — UX Sounds Guide
- PMC — Cognitive Load and Earcon Design

---

## Solution proposée

### Phase 1 : Document de référence psychoacoustique

Rédiger `_docs/SOUND_DESIGN.md` (ou `docs/sound-design.md` dans sand) — document transversal réutilisable pour tous les projets Arsis.

**Contenu** :
- Synthèse de la recherche (fréquences, intervalles, enveloppes)
- Guide de paramètres par type de notification
- Tableau de correspondance état/fréquence
- Sources et références

### Phase 2 : Outil de synthèse `sand-synth`

Script Python (`bin/sand-synth`) utilisant numpy + struct (zéro dépendance supplémentaire — numpy 2.4.2 et Python 3.14 déjà installés).

**Commandes** :

```bash
sand-synth presets                    # Lister les presets
sand-synth generate <preset> [out]    # Générer un son depuis un preset
sand-synth play <preset>              # Générer + jouer immédiatement
sand-synth pack <nom>                 # Générer un pack complet
sand-synth generate --freq 528 --dur 0.5 --decay 4 --harmonics "2:0.3:8,3:0.15:12" out.aiff
```

**Architecture** :

```
bin/sand-synth              # CLI Python (argparse)
synth/
  presets.json              # Définitions déclaratives des presets
  engine.py                 # Moteur de synthèse (numpy → AIFF)
```

**Capacités** :
- Synthèse de tons avec harmoniques et enveloppe exponentielle
- Séquences multi-notes (chimes, arpèges)
- Écriture directe en AIFF 16-bit 44.1kHz (format macOS natif)
- Presets déclaratifs JSON
- Fallback ffmpeg si numpy absent

**Presets initiaux** (basés sur la recherche) :

| Preset | Type | Fréquence | Description |
|--------|------|-----------|-------------|
| `zen-stop` | séquence | 440→660 Hz | Quinte juste ascendante, timbre kalimba |
| `zen-question` | séquence | 587→784 Hz | Quarte juste, fin ouverte, timbre celesta |
| `bell` | ton | 880 Hz | Cloche cristalline |
| `warm` | ton | 440 Hz | Ton chaud et doux |
| `chime` | séquence | Do-Mi-Sol | Carillon ascendant majeur |
| `drop` | séquence | Sol→Do | Goutte descendante |
| `pulse` | ton | 660 Hz | Impulsion rapide |

### Phase 3 : Pack "zen" pour sand-notify

Génération et intégration d'un pack `zen` dans le système existant.

```
~/.config/sand/sounds/zen/
  stop/
    zen-stop-1.aiff         # Variante quinte juste A4→E5
    zen-stop-2.aiff         # Variante tierce majeure C5→E5
  question/
    zen-question-1.aiff     # Variante quarte juste D5→G5
    zen-question-2.aiff     # Variante seconde majeure E5→F#5
```

Intégration : `sand-synth pack zen` génère directement dans le répertoire de packs, puis `sand-notify use zen` active le pack.

---

## Approches alternatives considérées

| Approche | Avantage | Inconvénient | Verdict |
|----------|----------|-------------|---------|
| Sons préfabriqués (freesound.org) | Rapide | Pas de contrôle sur les fréquences exactes | Complémentaire |
| IA (Stable Audio Open) | Sons organiques | Pas de contrôle précis, nécessite GPU | Rejeté |
| SoX en CLI | Syntaxe concise | Dépendance à installer, limité pour le complexe | Fallback possible |
| ffmpeg aevalsrc | Zéro dépendance | Expressions illisibles pour les sons riches | Fallback si numpy absent |
| **Python numpy** | **Contrôle total, zéro nouvelle dépendance** | **Code plus verbeux que SoX** | **Recommandé** |

---

## Acceptance Criteria

### Fonctionnels

- [ ] Document `docs/sound-design.md` rédigé avec synthèse recherche, guide paramètres, sources
- [ ] Script `sand-synth` fonctionnel avec commandes `presets`, `generate`, `play`, `pack`
- [ ] Presets déclaratifs JSON pour au minimum 7 sons
- [ ] Pack "zen" généré avec 2 variantes stop + 2 variantes question
- [ ] Pack "zen" jouable via `sand-notify use zen` puis hooks Claude Code
- [ ] Sons < 300 ms pour le cas fréquent, < 500 ms maximum
- [ ] Fondamentales dans la plage 400-800 Hz
- [ ] Intervalles consonants (quinte, quarte, tierce majeure)

### Non-fonctionnels

- [ ] Aucune dépendance supplémentaire à installer (numpy déjà présent)
- [ ] Génération instantanée (< 1s par son)
- [ ] Fichiers AIFF 16-bit 44.1kHz mono (compatibilité macOS native)
- [ ] Sons agréables après 200 écoutes consécutives (test subjectif)

### Quality Gates

- [ ] `bash -n bin/sand-synth` (si wrapper bash) ou `python -m py_compile` passe
- [ ] `afplay` joue correctement chaque son généré
- [ ] `sand-notify test stop` et `sand-notify test question` fonctionnent avec le pack zen
- [ ] Pas de clics ou artefacts audio (fade in/out correctement implémentés)

---

## Phases d'implémentation

### Phase 1 — Document de référence (~30 min)
- Rédiger `docs/sound-design.md` à partir de la recherche consolidée
- Structure : principes, paramètres par type, tableau fréquences, sources

### Phase 2 — Moteur de synthèse sand-synth (~1h)
- `synth/engine.py` : écriture AIFF, génération de tons, séquences multi-notes
- `synth/presets.json` : définitions déclaratives
- `bin/sand-synth` : CLI argparse (presets, generate, play, pack)
- Tests : générer tous les presets, vérifier avec afplay

### Phase 3 — Pack zen + intégration (~30 min)
- Concevoir les presets zen-stop et zen-question basés sur la recherche
- Générer le pack via `sand-synth pack zen`
- Tester avec `sand-notify use zen` + `sand-notify test stop/question`
- Ajuster les paramètres si nécessaire après écoute

---

## Risques et mitigations

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| Sons théoriquement bons mais subjectivement désagréables | Moyen | Itérer sur les presets, fournir plusieurs variantes |
| Numpy pas dispo sur un autre poste | Faible | Fallback ffmpeg intégré dans sand-synth |
| terminal-notifier ne joue pas les sons courts | Faible | Tester la durée minimale, ajuster si nécessaire |
| Module `aifc` absent en Python 3.13+ | Résolu | Écriture AIFF manuelle via struct (validé) |

---

## Considérations futures

- Ajouter des presets pour le hook `tool` (sons très courts ~100ms)
- Explorer la génération de sons binauraux pour le focus (nécessite stéréo)
- Intégrer `sand-synth` dans d'autres apps Arsis (daymon, feedbase)
- Interface interactive pour tester les paramètres en temps réel
- Export du document de référence vers `_docs/SOUND_DESIGN.md` au niveau workspace

---

## Références

### Recherche académique
- [ResearchGate — 528Hz Stress Study (2018)](https://www.researchgate.net/publication/327439522_Effect_of_528_Hz_Music_on_the_Endocrine_System_and_Autonomic_Nervous_System)
- [PubMed — 432Hz vs 440Hz Pilot Study](https://pubmed.ncbi.nlm.nih.gov/31031095/)
- [PubMed — Binaural Beats Meta-analysis](https://pubmed.ncbi.nlm.nih.gov/30073406/)
- [PMC — Neural Correlates of Consonance](https://pmc.ncbi.nlm.nih.gov/articles/PMC2804402/)
- [PMC — Cognitive Load and Earcon Design](https://pmc.ncbi.nlm.nih.gov/articles/PMC6210363/)
- [PMC — Ascending Tones and Positive Affect](https://pmc.ncbi.nlm.nih.gov/articles/PMC2694503/)
- [PMC — Pink Noise Meta-analysis (ADHD)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11283987/)

### Guidelines design
- [Microsoft Learn — Sound (Win32 UX)](https://learn.microsoft.com/en-us/windows/win32/uxguide/vis-sound)
- [Apple HIG — Playing Audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio)
- [Google Design — Sound & Silence](https://medium.com/google-design/designing-sound-and-silence-1b9674301ec1)
- [Slack Design — Notification Principles](https://slack.design/articles/how-we-layered-product-principles-to-refresh-slack-notifications/)

### Design sonore
- [Jim Reekes — Sosumi Story & Mac Startup Sound](https://reekes.net/sosumi-story-mac-startup-sound/)
- [Sound Advice — Toptal UX Sounds Guide](https://www.toptal.com/designers/ux/ux-sounds-guide)
- [UXmatters — Sound Design in UX](https://www.uxmatters.com/mt/archives/2024/08/the-role-of-sound-design-in-ux-design-beyond-notifications-and-alerts.php)
- [ResearchGate — Designing Emotional Sounds](https://www.researchgate.net/publication/388438697_Designing_Emotional_and_Intuitive_Sounds_for_Tech_Insights_From_Psychoacoustics)
