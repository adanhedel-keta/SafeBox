# SafeBox

SafeBox est conçu comme étant le premier ordinateur de votre enfant, que vous pouvez lui confier en toute tranquilité. 
En tirant profit des technologes du monde libre, l'objectif est de vous fournir une solution (presque) clefs en mains pour pouvoir accompagner votre enfant dans ses premiers pas sur Internet, en sachant que les contenus inappropriés ont hors de sa portée.

Comprenez bien cependant que les limitations techniques que nous avons mis en place ne remplacent pas complètement une bonne éducation numérique, et que votre enfant pourrait trouver des moyens de passer outre passé l'âge de 13 ans (moins s'il est surdoué !). N'hésitez pas à explorer toutes les ressources à votre disposition pour contribuer à créer un environnement d'apprentissage sain avec toute votre famille.

SafeBox, pour qu'Internet reste une cour de récréation pour tous.

## Prérequis

- Un PC Windows 11
- Code d'adminitration de l'ordinateur
- Une carte MicroSD d'au moins 32 Go
- Un Raspberry Pi 4 au minimum. Nous conseillons le Pi400 pour une première utilisation, mais tous les modèles 64 bits conviennent. N'hésitez pas à le choisir et l'accessoiriser avec votre enfant !
- Un peu de patience... N'hésitez pas à parcourir notre site pendant l'installation (45 minutes environ)

## Installation

Activez les scripts via PowerShell administrateur : Set-ExecutionPolicy Unrestricted
Téléchargez le fichier "custom_image.ps1", puis exécutez le en tant qu'administrateur. Il est recommandé d'effectuer ce travail sur un ordinateur disposant d'au moins 16 coeurs et 16 Go de mémoire vive (voir "Adaptation" plus bas dans le cas contraire). 

Dans votre dossier "Téléchargements", vous trouverez un fichier "2024-07-04-raspios-bookworm-arm64.img"

Utilisez "Rasbperry Pi Imager (https://downloads.raspberrypi.org/imager/imager_latest.exe) pour envoyer ce fichier sur une carte MicroSD.

Et voilà ! N'oubliez pas de désactiver les scripts à nouveau en lancant la commande Set-ExecutionPolicy Default

## Fonctions

- Raspberry PiOS Bookworm (sortie du 04 juillet 2024)
- Libre office installé
- Compte enfant sans privilèges configuré
- DNS alternatifs configurés (https://dns0.eu/kids)
- Blocage de Facebook, Instagram et Twitter (et services associés)

## Adaptation

Si votre ordinateur n'est pas assez puissant pour la configuration de base, modifiez les lignes 85 et 86 avec votre valeur de RAM (memory) et de CPU. Nous recommandons de vous limiter à 50% des valeurs de votre ordinateur (4096 si vous disposez de 8Go de RAM par exemple).

## Pour aller plus loin
Nous conseillons l'utilisation de Firefox comme navigateur, pour éviter les errements de Google avec son Manifest v3.
Pour sécuriser Youtube et Google, nous vous conseillons de mettre en place le contrôle parental Google (plus d'informations ici : https://families.google/intl/fr/familylink/).


## Contribution
Ce projet est issu d'un travail d'école. La maintenance en sera limitée. N'hésitez pas à forker le projet ou à proposer de nouvelles features à implémenter ! 


## Sources
Ce travail a en grande partie été inspiré de l'excellent article de Brett Weir : https://brettweir.com/blog/custom-raspberry-pi-image-no-hardware/


## License

[MIT](https://choosealicense.com/licenses/mit/)
[PiOS](https://www.raspberrypi.com/licensing/)
Fond d'écran : Copyright SPIN MASTERS LTD et Nickolodeon
