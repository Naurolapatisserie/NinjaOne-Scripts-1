# Sync-PatchStatus.ps1

## Aperçu

Ce script PowerShell récupère les informations de statut des correctifs (correctifs en attente, échoués et approuvés) depuis l'API NinjaOne et met à jour les champs personnalisés correspondants sur les appareils dans la plateforme NinjaOne. Il s'assure que les champs personnalisés `pendingPatches`, `approvedPatches` et `failedPatches` reflètent toujours l'état actuel des correctifs de chaque appareil. Il est recommandé de l'exécuter une fois par heure. Seules les valeurs qui ont changé seront modifiées.

## Prérequis

1. **PowerShell 7+** :
   Le script nécessite PowerShell 7 ou ultérieur.

2. **Configurer un Serveur API/Serveur de Documentation Automatisée**
   Suivez les instructions ici :
   [https://docs.mspp.io/ninjaone/getting-started](https://docs.mspp.io/ninjaone/getting-started)

3. **Champs Personnalisés dans NinjaOne** :
   Avant d'exécuter ce script, vous devez créer trois champs texte personnalisés au niveau de l'appareil dans NinjaOne :
   - `pendingPatches`
   - `approvedPatches`
   - `failedPatches`

   Ces champs seront mis à jour par le script pour refléter les états actuels des correctifs de chaque appareil.

   **Note :**
   - Pour créer un champ personnalisé dans NinjaOne :
     1. Naviguez vers **Administration** > **Appareils** > **Champs Personnalisés** (rôle ou global).
     2. Créez un nouveau champ personnalisé avec le nom correspondant à chaque champ requis.
   - Assurez-vous que les champs sont des champs **Multi-lignes**, et si les champs personnalisés de rôle sont correctement appliqués aux classes de stations de travail et serveurs `Windows`.

## Ce que Fait le Script

1. **Vérifie la Version PowerShell** :
   Si le script ne s'exécute pas dans PowerShell 7 ou ultérieur, il essaie de redémarrer dans `pwsh`.

2. **Charge le Module NinjaOneDocs** :
   Installe et importe le module `NinjaOneDocs` si nécessaire.

3. **Récupère les Identifiants API** :
   Utilise `Ninja-Property-Get` pour récupérer `ninjaoneInstance`, `ninjaoneClientId` et `ninjaoneClientSecret`.

4. **Se Connecte à l'API NinjaOne** :
   Utilise `Connect-NinjaOne` pour établir une session.

5. **Récupère les Informations d'Appareils et de Correctifs** :
   Interroge l'API NinjaOne pour les appareils et leur statut de correctifs associé (correctifs en attente, échoués et approuvés).

6. **Met à Jour les Champs Personnalisés** :
   Pour chaque appareil, le script compare la valeur actuelle des champs `pendingPatches`, `approvedPatches` et `failedPatches` aux données de correctifs réelles récupérées depuis l'API. S'il y a une différence :
   - Le script met à jour le champ personnalisé avec les derniers noms de correctifs.

7. **Supprime les Données Obsolètes** :
   Si un appareil n'a plus de correctifs en attente, échoués ou approuvés (basé sur les données API actuelles) mais que le champ personnalisé contient encore d'anciennes valeurs, le script les efface.
