# Variables de Script : Modes de Planification & Paramètres

Ce document décrit les variables de script configurables utilisées pour définir le comportement de planification dans le script. La planification est contrôlée par une combinaison de modes d'exécution (`Mode`) et de paramètres de support qui varient selon le mode sélectionné.

---

## 📋 Aperçu des Variables de Script

| Variable                  | Utilisée Pour                  | Type      | Notes                                                                 |
|---------------------------|---------------------------|-----------|-----------------------------------------------------------------------|
| `Mode`                   | Type d'exécution             | LISTE DÉROULANTE  | Requis. Options : `Once`, `Daily`, `Weekly`, `Monthly`, `Window`    |
| `Target Time`            | Heure ou DateTime           | DATETIME  | DateTime complet pour `Once`, heure seulement pour `Daily`, `Weekly`, et `Monthly` |
| `Weekly Day Of Week`     | Mode hebdomadaire                | TEXTE      | Jours séparés par des virgules (ex. `Monday,Wednesday`)                      |
| `Monthly Day Of Month`   | Mode mensuel               | ENTIER   | Jour numérique du mois (1–31)                                      |
| `Window Recurrence`      | Récurrence de fenêtre          | LISTE DÉROULANTE  | Requis pour le mode `Window`. Options : `Daily`, `Weekly`               |
| `Window Start`           | Début de fenêtre            | DATETIME  | Seule l'heure est utilisée                                                       |
| `Window End`             | Fin de fenêtre              | DATETIME  | Seule l'heure est utilisée                                                       |
| `Window Day of Week`     | Mode fenêtre hebdomadaire         | TEXTE      | Requis si `Window Recurrence` est `Weekly` ; séparés par des virgules         |

---

## 🔄 Comportement des Modes et Champs Requis

### `Once`
- **Utilise** : `Target Time` complet (date et heure)
- **Requis** : `Target Time`

### `Daily`
- **Utilise** : Heure de `Target Time`
- **Requis** : `Target Time`

### `Weekly`
- **Utilise** : Heure de `Target Time` et `Weekly Day Of Week`
- **Requis** : `Target Time`, `Weekly Day Of Week`

### `Monthly`
- **Utilise** : Heure de `Target Time` et `Monthly Day Of Month`
- **Requis** : `Target Time`, `Monthly Day Of Month`

### `Window`
- **Utilise** : `Window Recurrence`, `Window Start`, `Window End`, optionnellement `Window Day of Week`
- **Requis** :
  - `Window Recurrence`
  - `Window Start`
  - `Window End`
  - `Window Day of Week` (si la récurrence est `Weekly`)

---
**Note Importante sur les Réinitialisations de Conditions et les Timeouts de Script**

Il n'est pas recommandé d'utiliser "When no longer" pour aucun mode - utilisez uniquement les réinitialisations basées sur le temps.

Pour tout mode, il est important d'ajuster la variable $TimeWindowMinutes dans le script pour être synchronisée avec votre intervalle et timeout de script. Par exemple, si j'exécute ma condition composée toutes les 15 minutes, je définirais mon $TimeWindowMinutes à 16 minutes. Cela permet au script de dormir jusqu'à ce que le $TargetTime désiré soit atteint. Je dois m'assurer que le timeout du script dépasse mon $TimeWindowMinutes - donc dans mon cas je le mettrais à 17 minutes.
-Intervalle du script
-$TimeWindowMinutes = intervalle + 1 minute
-Timeout du script = intervalle + 2 minutes

Lors de l'utilisation du mode Window, il devient également important de s'assurer que la réinitialisation automatique est plus longue que la fenêtre de maintenance - c.-à-d. une fenêtre de maintenance de 4 heures devrait avoir un temps de réinitialisation automatique de 4 heures ou plus. Si la réinitialisation est trop courte, l'automatisation pourrait potentiellement se déclencher à nouveau s'il n'y a pas un moniteur de changement d'état adéquat dans la condition composée.
