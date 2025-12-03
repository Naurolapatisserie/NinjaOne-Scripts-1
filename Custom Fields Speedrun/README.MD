# Script d'Importation d'Appareils et de Mise à Jour de Champs Personnalisés via API NinjaOne

Ce script démontre comment interagir avec l'API NinjaOne, importer des données d'appareils depuis un CSV, les faire correspondre avec les appareils de NinjaOne, et mettre à jour les champs personnalisés dynamiquement basé sur les en-têtes CSV.
Il inclut une gestion d'erreurs améliorée, la journalisation et la génération dynamique du corps de requête. Ceci n'a été testé qu'avec les types de champs personnalisés texte, multi-lignes et case à cocher. Seuls les types de champs qui acceptent une valeur chaîne sont susceptibles de fonctionner, tout ce qui implique des pièces jointes ou des champs WYSIWYG ne fonctionnera probablement pas.

Vous pouvez voir ce script en action ici : https://www.youtube.com/watch?v=QvDygAJrlq0 (vers 31:40)

Exemple de CSV utilisé pour importer des données pendant le webinaire : https://github.com/jeffhunterninja/NinjaOne-Scripts/blob/main/Custom%20Fields%20Speedrun/datatoimport.csv

## Paramètres

### `$OverwriteEmptyValues`
- **Description** : Détermine si les valeurs CSV vides sont incluses comme `$null` (écrasant les données existantes) ou exclues de la charge utile de mise à jour.
- **Valeur par Défaut** : `$false`

## Prérequis

Avant d'exécuter ce script, assurez-vous de ce qui suit :

1. Le fichier CSV (`csvexample.csv`) doit avoir au moins les colonnes suivantes :
   - `Id`
   - `Name`
2. Les colonnes supplémentaires (ex. `assetOwner`, `location`, etc.) seront utilisées comme champs personnalisés.
3. Remplacez les espaces réservés suivants dans le script par vos valeurs réelles :
   - `$NinjaOneClientId`
   - `$NinjaOneClientSecret`
   - `$csvPath` (Chemin vers le fichier CSV)

## Utilisation

Exécutez le script dans PowerShell avec les paramètres requis :

```powershell
.\ScriptName.ps1 -OverwriteEmptyValues $true
