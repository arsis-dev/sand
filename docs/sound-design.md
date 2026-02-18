# Sound Design — Sand Notify

Guide de conception sonore pour les notifications sand, basé sur la recherche psychoacoustique.

## Principes

1. **Non-intrusif** — Les sons doivent informer sans stresser. Éviter les fréquences aiguës pures (>2kHz) et les attaques brutales.
2. **Distinct** — Chaque type de notification (stop, question, tool) doit être immédiatement reconnaissable.
3. **Court** — Durée maximale 700ms. Le cerveau identifie un son en ~100ms ; au-delà, ça devient intrusif.
4. **Harmoniquement riche** — Les sons purs (sinusoïdes) sont perçus comme artificiels. Ajouter des harmoniques crée chaleur et naturel.
5. **Decay naturel** — Les sons naturels (cloches, bois) déclinent exponentiellement. Imiter ce comportement.

## Paramètres par type

### Stop (tâche terminée)

- **Émotion** : satisfaction, résolution, accomplissement
- **Intervalle** : quinte juste (3:2) ou tierce majeure (5:4) — consonance maximale
- **Fréquences** : 400-700 Hz (registre médium, chaleureux)
- **Mouvement** : ascendant (note grave → note aiguë)
- **Decay** : modéré (6-8), le son doit résonner doucement
- **Durée** : 300-350ms

### Question (attente d'input)

- **Émotion** : interrogation douce, curiosité, invitation
- **Intervalle** : quarte juste (4:3) — tension légère sans inconfort
- **Fréquences** : 500-800 Hz (légèrement plus aigu que stop)
- **Mouvement** : ascendant avec plus d'élan (écart plus grand)
- **Decay** : rapide (4-5), son plus vif pour attirer l'attention
- **Durée** : 250-300ms

### Tool (appel d'outil)

- **Émotion** : neutre, subtil, feedback minimal
- **Fréquence** : ton unique, 600-700 Hz
- **Decay** : très rapide (12+), quasi-percussif
- **Durée** : 100-150ms
- **Volume** : réduit (-30% vs stop/question)

## Tableau de fréquences

| Note  | Hz   | Contexte d'usage                        |
|-------|------|-----------------------------------------|
| A4    | 440  | Fondamentale warm, stop (base)          |
| C5    | 523  | Stop variante, chime (base)             |
| D5    | 587  | Question (base)                         |
| E5    | 659  | Stop résolution, question variante      |
| G5    | 784  | Question résolution, chime (milieu)     |
| A5    | 880  | Bell, question variante (résolution)    |

## Intervalles psychoacoustiques

| Intervalle       | Ratio | Perception                  | Usage        |
|------------------|-------|-----------------------------|--------------|
| Quinte juste     | 3:2   | Stable, complète            | Stop         |
| Tierce majeure   | 5:4   | Chaleureuse, joyeuse        | Stop variante|
| Quarte juste     | 4:3   | Ouverte, interrogative      | Question     |
| Octave           | 2:1   | Neutre, claire              | Bell         |

## Harmoniques et timbre

Les harmoniques définissent le « caractère » du son :

- **[2, 0.3, 8]** — Octave à 30%, decay 8 : ajoute de la rondeur
- **[3, 0.15, 12]** — Quinte d'octave : brillance légère
- **[4.5, 0.08, 15]** — Inharmonique : couleur de cloche (battement subtil)

Règle : les harmoniques supérieures doivent avoir un decay plus rapide que la fondamentale (simule les matériaux naturels).

## Enveloppe

```
amplitude
  │  ╱╲
  │ ╱  ╲
  │╱    ╲__________
  └──────────────── temps
  │2ms│   decay exponentiel
  fade-in
```

- **Fade-in** : 2ms (anti-click, évite le pop numérique)
- **Decay** : `exp(-decay * t)` — plus le decay est élevé, plus le son est court
- **Fade-out** : 10% de la durée totale (atterrissage doux)

## Sources

- Fastl & Zwicker, *Psychoacoustics: Facts and Models* (Springer) — référence sur la perception auditive
- Études sur les tons d'alerte en cockpit (Patterson, 1982) — design de sons d'alerte non-stressants
- Recherche UX sur les sons de notification (Harrison et al., 2010) — impact émotionnel des notifications sonores
