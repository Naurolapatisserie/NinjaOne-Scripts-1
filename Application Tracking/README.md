# Suivi des Applications

Ces scripts constituent la base d'un framework qui vous permet d'utiliser **NinjaOne** pour établir une liste blanche d'applications autorisées dans un **champ personnalisé d'organisation** et comparer les applications installées sur un appareil avec cette liste blanche. Vous pouvez également ajouter des exceptions par appareil dans un **champ personnalisé d'appareil** optionnel. Les applications non autorisées sont écrites dans un champ personnalisé à des fins d'alerte/rapport.

Ce flux de travail peut ne pas être réalisable selon votre environnement. Par exemple :

- Si chaque utilisateur a des droits d'administrateur ou d'installation, les alertes atteindront éventuellement un volume insoutenable.
- Les utilisateurs habitués à avoir des droits d'installation peuvent ne pas réagir positivement à leur retrait
- Cependant, si les utilisateurs sont déjà verrouillés, cela pourrait être un outil utile pour identifier les installations d'applications inattendues.

**Seuls les appareils Windows sont pris en charge aujourd'hui**

> **Recommandation :** Utilisez ce processus principalement pour suivre l'utilisation des applications sur les terminaux en tant que **rapport périodique**, plutôt que pour des processus de sécurité/opérationnels nécessitant des réponses immédiates.

---

## Étapes

Avant d'utiliser ces scripts, il y a quelques **prérequis** :

### 1. Configurer un Serveur API/Serveur de Documentation Automatisée
Suivez les instructions ici :
[https://docs.mspp.io/ninjaone/getting-started](https://docs.mspp.io/ninjaone/getting-started)

---

### 2. Configuration des Champs Personnalisés

Créez les champs personnalisés suivants avec les permissions spécifiées. Vous pouvez renommer ces champs, mais vous devez modifier les scripts en conséquence.

| **Nom**                   | **Nom d'affichage**             | **Permissions**                                                                 | **Portée**               | **Type**                                |
|----------------------------|------------------------------|---------------------------------------------------------------------------------|-------------------------|-----------------------------------------------|
| **softwareList**           | Liste des logiciels                | - Lecture seule pour les techniciens  <br> - Lecture seule pour les automatisations <br> - Lecture/Écriture pour l'API | Organisation et Appareil | WYSIWYG  |
| **deviceSoftwareList**     | Liste des logiciels de l'appareil         | - Lecture seule pour les techniciens <br> - Lecture seule pour les automatisations <br> - Lecture/Écriture pour l'API | Appareil                  | WYSIWYG |
| **unauthorizedApplications** | Applications non autorisées   | - Lecture seule pour les techniciens <br> - Lecture/Écriture pour les automatisations <br> - Lecture seule pour l'API | Appareil                  | Multi-ligne |


---

### 3. Importer les Scripts

Importez les scripts de ce dépôt dans **NinjaOne**. Chaque script a des variables de script qui doivent être créées dans l'éditeur de scripts NinjaOne.

---

## Script : Check-AuthorizedApplications

### Exécution
Exécuter en tant que **condition de résultat de script**.

### Variables de Script Requises

Créez ces variables dans l'éditeur de scripts NinjaOne :

| **Nom**              | **Nom affiché**                          | **Type de variable de script** |
|-----------------------|------------------------------------------|--------------------------||
| **matchingCriteria**  | Critères de correspondance                       | Liste déroulante                |

Cette variable contrôle le mode de correspondance du script. Entrez toutes les options de la colonne **Mode** comme options pour la variable de script liste déroulante.

## Mode de Correspondance

| **Mode**            | **Sensible à la casse** | **Comportement de correspondance**                  | **Cas d'utilisation**                      |
|----------------------|--------------------|----------------------------------------|-----------------------------------|
| **Exact**           | Oui                | Correspondances de chaînes identiques uniquement    | Quand la précision est critique.       |
| **CaseInsensitive** | Non                 | Correspond aux chaînes identiques, ignore la casse| Quand des différences de casse existent.      |
| **Partial**         | Oui                | Vérifie si l'app autorisée est une sous-chaîne| Pour des comparaisons souples ou floues.   |

---

## Script : Update-AuthorizedApplications

### Exécution
Exécuter selon les besoins depuis le Serveur API/Serveur de Documentation Automatisée pour mettre à jour les applications autorisées au niveau de l'organisation ou de l'appareil.

### Variables de Script Requises  

| **Nom**                                    | **Nom affiché**                                | **Type de variable de script** |
|-------------------------------------------|--------------------------------------------|--------------------------||
| **commaSeparatedListOfOrganizationsToUpdate** | Liste séparée par virgules des organisations à mettre à jour | Texte              |
| **updateOrganizationsBasedOnCurrentSoftwareInventory** | Mettre à jour les organisations selon l'inventaire logiciel actuel | Case à cocher                  |
| **appendToOrganizations**                   | Ajouter aux organisations                     | Texte              |
| **softwareToAppend**                        | Logiciel à ajouter                          | Texte              |
| **removeFromOrganizations**                 | Supprimer des organisations                   | Texte              |
| **softwareToRemove**                        | Logiciel à supprimer                          | Texte              |
| **appendToDevices**                         | Ajouter aux appareils                           | Texte              |
| **deviceSoftwareToAppend**                  | Logiciel d'appareil à ajouter                   | Texte              |
| **removeFromDevices**                       | Supprimer des appareils                         | Texte              |
| **deviceSoftwareToRemove**                  | Logiciel d'appareil à supprimer                   | Texte              |

---

### Fonctions Principales du Script

1. **Autoriser les Applications Installées :**
   - Autoriser toutes les applications actuellement installées dans toutes les organisations.
   - Autoriser les applications pour des organisations sélectionnées en utilisant une liste séparée par virgules.
   - **L'utilisation de cette option écrasera les données déjà présentes dans les champs personnalisés de l'organisation**

2. **Ajouter des Applications aux Organisation(s) :**
   - Ajouter des logiciels aux applications autorisées pour toutes ou certaines organisations.

3. **Supprimer des Applications des Organisation(s) :**
   - Supprimer des logiciels des applications autorisées pour toutes ou certaines organisations.

4. **Exceptions par Appareil :**
   - Ajouter ou supprimer des logiciels pour des appareils spécifiques.

---

## Script : Recover-AuthorizedApplications

### Exécution
Exécuter sur une **cadence quotidienne** pour sauvegarder ou restaurer selon les besoins.

### Variables de Script Requises
Pour les sauvegardes, seule la variable **Action** doit être saisie.
Un **BackupFile** ou **BackupDirectory** doit être spécifié pour les restaurations, et un **TargetType** doit être sélectionné.

| **Nom**              | **Nom affiché**                          | **Type de variable de script** |
|-----------------------|------------------------------------------|--------------------------||
| **Action**            | Action                                  | Liste déroulante                |
| **BackupFile**        | Fichier de sauvegarde                             | Texte              |
| **BackupDirectory**   | Répertoire de sauvegarde                        | Texte              |
| **TargetType**        | Type de cible                             | Liste déroulante                |
| **RestoreTargets**    | Cibles de restauration                         | Texte              |

> **Recommandation :** Exécutez le script de sauvegarde **quotidiennement** ou **hebdomadairement**.

---

## Script : Report-UnauthorizedApplications

> **Prérequis :** Ce script utilise le module PowerShell NinjaOneDocs situé ici : [https://github.com/lwhitelock/NinjaOneDocs/tree/main/Public](https://github.com/lwhitelock/NinjaOneDocs/tree/main/Public).

Ce script produit :

- Une liste séparée par virgules des applications non autorisées dans tout l'environnement.
- Une exportation CSV des applications non autorisées par appareil avec chaque emplacement et organisation dans C:\temp.

> **Note :** Cela dépend du champ personnalisé "Applications non autorisées". Les agents hors ligne peuvent ne pas mettre à jour le champ jusqu'à ce qu'ils reviennent en ligne.

---

## Mises en Garde et Avertissements

- **Installations en contexte utilisateur :**
  NinjaOne ne suit pas les installations en contexte utilisateur par défaut.

- **Pas de Zero-Trust :**
  Ce framework n'empêche pas l'élévation de privilèges mais fournit des informations sur les installations inattendues.

- **Faux Positifs :**
  Attendez-vous à des faux positifs, notamment dus aux changements de noms d'applications. La **correspondance partielle** peut aider à les réduire mais augmente le risque de manquer des installations non autorisées.

- **Stratégie de Réponse :**
  Répondre aux applications non autorisées nécessite du temps. Sans contrôles utilisateur adéquats, les alertes peuvent rapidement s'accumuler.

> **Recommandation :** Examinez les applications non autorisées sur une cadence **hebdomadaire** ou **mensuelle** pour la durabilité.

---
