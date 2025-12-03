# ✋ Script de Notification de Champ Personnalisé NinjaOne

Ce script PowerShell définit un champ personnalisé dans NinjaOne avec un emoji (`✋`) pour indiquer un statut ou notifier les utilisateurs. Après un bref délai, le champ est automatiquement effacé. C'est utile pour les indicateurs visuels ou les drapeaux sensibles au temps dans NinjaOne. Les administrateurs peuvent également créer une condition qui surveille la présence de l'emoji main pour simplifier le processus de soumission de ticket/"appel à l'aide".

---

## 🧰 Prérequis

- La **variable de formulaire de script** `customFieldName` doit être définie, contenant le nom du champ personnalisé à cibler. Alternativement, le nom du champ personnalisé peut être codé en dur dans le script.

---

## ⚙️ Ce que Fait le Script

1. Vérifie que la cmdlet `Ninja-Property-Set` existe.
2. Définit le champ personnalisé spécifié à `✋`.
3. Attend **3 minutes**.
4. Efface le champ personnalisé.

---

## 🛠️ Utilisation

### 1. Définir la Variable d'Environnement Requise

Avant d'exécuter le script, définissez le nom du champ personnalisé comme variable d'environnement :

```powershell
$env:customFieldName = "VotreNomDeChampPersonnalisé"
```
---

## 🧼 Nettoyage

Le script efface automatiquement le champ personnalisé après le délai, s'assurant que les notifications temporaires ne persistent pas.

---

## 📌 Notes

- Vous pouvez changer l'emoji ou le message en modifiant la variable `$Message`.
- Vous pouvez ajuster le délai en changeant la valeur `Start-Sleep -Seconds` (actuellement définie à 180 secondes = 3 minutes).
