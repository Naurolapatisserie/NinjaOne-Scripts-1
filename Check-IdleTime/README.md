## 📘 Aperçu

Ce script PowerShell mesure le **temps d'inactivité par utilisateur** sur les terminaux Windows, même lorsqu'il est exécuté en tant que **SYSTEM** - ce qui est nécessaire pour interagir avec les champs personnalisés NinjaOne.

Il fonctionne en lançant un assistant PowerShell léger **dans chaque session utilisateur connectée**, qui appelle `GetLastInputInfo` pour déterminer depuis combien de temps l'utilisateur est inactif.

### ✅ Fonctionnalités Clés

- Mesure le temps d'inactivité **par utilisateur** via l'API Windows
- S'exécute en tant que **SYSTEM** avec `CreateProcessAsUser` pour chaque session
- Sélectionne la session la plus pertinente (Console > Active la plus inactive > n'importe laquelle)
- Écrit dans les **champs personnalisés NinjaOne**
- Prend en charge les seuils d'inactivité configurables
- Retourne des **codes de sortie** standardisés pour l'automatisation des politiques - c.-à-d. appliquer les correctifs uniquement quand le temps d'inactivité a dépassé un certain seuil.

### ⚙️ Codes de Sortie

| Code | Signification |
|------|----------|
| `0`  | OK — aucun seuil défini ou inactivité inférieure au seuil |
| `1`  | Non élevé (doit s'exécuter en tant que SYSTEM) |
| `2`  | ALERTE — temps d'inactivité ≥ seuil |

---

## 🧩 Comment Ça Fonctionne

### 1. Vérification de l'Élévation

S'assure que le script s'exécute avec les privilèges Administrateur.
Sinon, il se termine immédiatement avec le code **1**.

### 2. Collecte des Résultats

Le script principal collecte les résultats pour toutes les sessions actives (`WTSActive`, `WTSConnected`, ou `WTSIdle`) :

| Propriété | Description |
|-----------|--------------|
| `SessionId` | ID de session Windows |
| `WinStation` | Nom de session (ex. Console, RDP-Tcp#5) |
| `State` | État de la session |
| `IdleMinutes` | Minutes d'inactivité calculées |
| `IdleSeconds` | Secondes d'inactivité calculées |
| `MeasuredVia` | Méthode ou statut (ex. `CreateProcessAsUser:GetLastInputInfo` ou `Failed`) |

### 3. Sélection de Session

Le script priorise quelle session évaluer :

1. Session Console (si disponible)
2. Session active la plus inactive
3. Toute autre session mesurée (repli)

### 4. Mises à Jour des Champs Personnalisés NinjaOne

Deux champs personnalisés sont mis à jour :

| Champ | Type | Valeur Exemple | Description |
|--------|------|----------------|--------------|
| `idleTime` | Texte | `1 hour(s), 20 minute(s)` | Durée d'inactivité lisible |
| `idleTimeStatus` | Texte | `ALERT: Idle 85 min (>= 60)` ou `85` | Minutes numériques ou texte d'alerte |

### 5. Gestion du Seuil

Si un seuil est défini (`ThresholdMinutes` ou variable d'env `thresholdminutes`) :

- Quand le temps d'inactivité ≥ seuil :
  → Écrit une alerte dans `idleTimeStatus` et se termine avec le code **2**
- Sinon :
  → Écrit le temps d'inactivité numérique et se termine avec **0**

---

## 🔧 Paramètres et Variables d'Environnement

Créez une Variable de Formulaire de Script appelée "Threshold Minutes" si vous voulez spécifier une durée qui constituera un appareil inactif.

```powershell
$ThresholdMinutes = $env:thresholdminutes
```

---

## 🧱 Configuration dans NinjaOne

### 1. Créer les Champs Personnalisés d'Appareil

Créez deux champs personnalisés dans NinjaOne sous **Appareils → Champs Personnalisés** :

| Nom | Type | Objectif |
|------|------|----------|
| `idleTime` | Texte | Stocke la durée d'inactivité lisible |
| `idleTimeStatus` | Texte | Stocke soit les minutes numériques soit une chaîne d'alerte |

### 2. Ajouter le Script

| Paramètre | Valeur |
|----------|--------|
| **Type** | PowerShell |
| **OS** | Windows |
| **Exécuter en tant que** | SYSTEM |
| **Version PowerShell** | 5.1 |
| **Politique d'Exécution** | Bypass |
| **Timeout** | ≥ 60 secondes recommandé |

Collez le script original complet dans le corps du script.

### 3. Configurer les Seuils

#### Créer une variable de script
Définissez une variable de script dans le script appelée "Threshold Minutes" qui utilise le type de données "Integer".

---

## 🧾 Exemples de Sorties

### Exemple 1 — Sans Seuil
```
=== Summary ===
ComputerName       : DESKTOP123
IdleMinutes        : 38
IdleTime           : 38 minute(s)
ThresholdMinutes   : 0
ThresholdExceeded  : False
UsedFallback       : False
```

Champs Personnalisés :
```
idleTime: 38 minute(s)
idleTimeStatus: 38
Code de Sortie: 0
```

---

### Exemple 2 — Seuil Dépassé
```
Idle time threshold exceeded: 85 minute(s) (threshold: 60).
```

Champs Personnalisés :
```
idleTime: 1 hour(s), 25 minute(s)
idleTimeStatus: ALERT: Idle 85 min (>= 60)
Code de Sortie: 2
```

---

## 🔍 Dépannage

| Problème | Cause Probable | Solution |
|--------|--------------|-----------|
| `Access Denied` / Code de Sortie 1 | Script non élevé | Exécuter en tant que **SYSTEM** |
| `(No sessions measured or all failed)` | Aucun utilisateur interactif | Confirmer qu'un utilisateur est connecté |
| Temps d'inactivité incorrect | Session différente évaluée | Vérifier le tableau par session |
| Seuil ignoré | Remplacement de variable d'env | Supprimer ou mettre à jour `thresholdminutes` |
| Champs personnalisés non mis à jour | CFs manquants ou mal nommés | Vérifier les noms exacts des champs |

---

## 🧠 Détails Techniques

- **API Windows :** Utilise `GetLastInputInfo` pour un suivi précis de l'inactivité.
- **Gestion des Sessions :** Via `WTSEnumerateSessions` et `CreateProcessAsUser`.
- **États Pris en Charge :** `WTSActive`, `WTSConnected`, `WTSIdle`.
- **Contexte d'Exécution :** Doit être **SYSTEM** pour accéder aux autres sessions.
- **Gestion de TickCount :** Utilise l'arithmétique non signée pour éviter le débordement.
- **Gestion des Erreurs :** Tous les appels `Ninja-Property-Set` encapsulés dans `try/catch`.

---

> 🧩 **Note de l'Auteur :**
> Ce script est fourni tel quel et ne relève pas du support normal de NinjaOne.
