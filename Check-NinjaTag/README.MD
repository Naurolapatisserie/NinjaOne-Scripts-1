# Documentation du Script : Évaluation de Présence de Tags NinjaOne

Ce script vérifie si les tags spécifiés sont présents sur l'appareil actuel en utilisant l'API NinjaOne. Il prend en charge deux modes d'évaluation : `ANY` et `ALL`.

---

## 📋 Aperçu des Variables de Script

| Variable          | Utilisée Pour                             | Type     | Notes                                                                 |
|-------------------|--------------------------------------|----------|-----------------------------------------------------------------------|
| `Tags To Search` | Tags à rechercher                     | TEXTE     | Requis. Accepte un seul tag ou une liste de tags séparés par des virgules      |
| `Mode`           | Comportement de correspondance                    | LISTE DÉROULANTE | Optionnel. Valeurs : `ANY` ou `ALL` (insensible à la casse). Par défaut `ANY` si omis |

---

## 🔎 Logique de Correspondance des Tags

### `Tags To Search`
- Accepte une liste de tags séparés par des virgules à évaluer (ex. `Critical,Production,VIP`)
- Les espaces sont supprimés de chaque tag
- Les tags sont évalués par rapport aux tags assignés de l'appareil actuel (via `Get-NinjaTag`)

### `Mode`
- Détermine comment la correspondance de tag est évaluée :
  - **`ANY`** : Le script se termine avec succès si **n'importe lequel** des tags spécifiés est présent
  - **`ALL`** : Le script se termine avec succès uniquement si **tous** les tags spécifiés sont présents
- Une comparaison insensible à la casse est appliquée

---
