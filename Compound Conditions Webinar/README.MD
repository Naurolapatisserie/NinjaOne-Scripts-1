Merci à tous ceux qui ont assisté au webinaire sur les Conditions Composées, que vous pouvez trouver sur YouTube ici : https://youtu.be/y7WvImYobJ0

## Premier Exemple : Déploiement de Logiciels avec Conditions Composées

Le premier exemple portait sur le déploiement de logiciels en utilisant une condition composée pour vérifier l'absence d'un logiciel (Google Chrome dans ce cas), tout en recherchant la chaîne de texte **"Google Chrome"** dans un champ personnalisé.

Pour mettre à jour plus facilement, vous pouvez utiliser un serveur de documentation automatisée ou un serveur API pour mettre à jour en masse et ajouter aux champs personnalisés.

### Étapes :
- **En savoir plus sur la configuration d'un serveur API ici :** [Configuration API NinjaOne](https://docs.mspp.io/ninjaone/getting-started)
- **Configurer un champ personnalisé multi-lignes** avec la portée 'Organisation', avec des capacités Lecture/Écriture pour l'API et Lecture seule pour les automatisations.
  - Que vous vouliez que les techniciens puissent modifier ce champ dépend de vous—sinon, seuls les administrateurs système pourraient mettre à jour, supprimer et ajouter des logiciels pour le déploiement en utilisant la méthode du serveur API.
  - Si les techniciens peuvent le modifier, il est recommandé de sauvegarder régulièrement la liste des applications à installer via API.
- **Configurer un second champ personnalisé multi-lignes** avec la portée 'Appareil' pour que les applications puissent être spécifiées par appareil.

### Script pour Mettre à Jour les Logiciels Déployés
Accédez au script pour mettre à jour les logiciels déployés ici, et importez-le dans NinjaOne.

#### Variables de Script Requises :
| Nom | Nom Affiché | Type de Variable de Script |
|------|------------|----------------------|
| `appendToOrganizations` | Ajouter aux Organisations | Texte |
| `softwareToAppend` | Logiciel à Ajouter | Texte |
| `removeFromOrganizations` | Supprimer des Organisations | Texte |
| `softwareToRemove` | Logiciel à Supprimer | Texte |
| `appendToDevices` | Ajouter aux Appareils | Texte |
| `deviceSoftwareToAppend` | Logiciel d'Appareil à Ajouter | Texte |
| `removeFromDevices` | Supprimer des Appareils | Texte |
| `deviceSoftwareToRemove` | Logiciel d'Appareil à Supprimer | Texte |

Vous pouvez maintenant utiliser le serveur API et le script `Update-SoftwareDeployment` pour commencer à créer une liste séparée par virgules des applications qui devraient être installées pour une organisation. Ensuite, créez une **condition composée** recherchant :
1. L'absence de ce logiciel.
2. La chaîne de texte identifiant votre application qui se trouve dans votre/vos champ(s) personnalisé(s).

---

## Deuxième Exemple : Suivi des Applications Autorisées

Le deuxième exemple était une **inversion du premier**—au lieu de configurer des applications pour le déploiement, cette approche établit une **liste d'applications autorisées** dans un champ personnalisé WYSIWYG de portée organisation et/ou appareil.

📌 **Documentation complète et scripts pour ce flux de travail :**
[GitHub - Suivi des Applications NinjaOne](https://github.com/jeffhunterninja/NinjaOne-Scripts/tree/main/Application%20Tracking)

### Aperçu du Flux de Travail :
- **`Check-AuthorizedApplications`** s'exécute en tant que **condition de résultat de script** dans le cadre d'une condition composée.
  - Une **condition de champ personnalisé** (ex. une case à cocher) peut être utilisée comme interrupteur d'activation si vous ne voulez pas que ces vérifications s'appliquent à toutes les organisations.
- **`Update-AuthorizedApplications`** s'exécute sur votre serveur API et est utilisé pour :
  - Mettre à jour, supprimer ou ajouter des noms d'applications à une **chaîne séparée par virgules** stockée dans un champ WYSIWYG au niveau de l'organisation ou de l'appareil.
- **`Recover-AuthorizedApplications`** sauvegarde votre chaîne séparée par virgules stockée avec une **option de restauration** si nécessaire.
- **`Report-UnauthorizedApplications`** récupère toutes les applications non autorisées actuellement signalées pour :
  - Une **vue globale** des applications non autorisées.
  - Une **mise en liste blanche à grande échelle** plus facile.

## Troisième Exemple : Utilisation de la Documentation NinjaOne pour la Configuration des Appareils

Le troisième exemple utilisait la **Documentation NinjaOne** pour créer un document avec des **cases à cocher de champs personnalisés** qui indiquent si certaines configurations d'appareils doivent être activées ou non.

### Processus :
1. **Cases à Cocher de Champs Personnalisés**
   - Un document est créé dans la **Documentation NinjaOne** avec des cases à cocher qui spécifient si certaines configurations d'appareils doivent être activées (ex. "Activer le Pare-feu").

2. **Condition de Résultat de Script (Vérifier l'Intention de Configuration)**
   - Une **condition de résultat de script** est utilisée dans le cadre d'une **condition composée** pour vérifier si la case est cochée dans la documentation - ce script ici : https://github.com/jeffhunterninja/NinjaOne-Scripts/blob/main/Compound%20Conditions%20Webinar/Check%20Device%20Configurations%20Document.ps1

3. **Condition de Résultat de Script (Vérifier l'État de l'Appareil)**
   - Une seconde **condition de résultat de script** évalue l'**état réel de l'appareil**.
   - Par exemple, si le document **Configuration de l'Appareil** a la case cochée pour **"Activer le Pare-feu"**, le script de la bibliothèque de modèles **"Audit Firewall Status"** est utilisé pour confirmer si le pare-feu est réellement activé sur l'appareil.
