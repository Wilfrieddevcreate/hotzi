# Hotzi · app vendeur (Flutter)

L'application du vendeur : forfaits, vente de tickets avec QR code, historique des ventes, code secret et Wi-Fi Hotzi. Le design suit le canvas validé (palette Violet & Mangue, logo « Lever de soleil »).

## Comment elle est construite

- **L'interface** est en Flutter (`lib/`).
- **Le Wi-Fi et les données** sont dans la bibliothèque Kotlin `android/net`, incluse dans le projet Android de l'app. Les données y vivent pour que le service qui coupe les clients les lise même quand l'app est fermée.
- **Le pont** entre les deux est dans `android/app/src/main/kotlin/com/hotzi/hotzi/HotziBridge.kt` :
  - `hotzi/data` : forfaits, tickets, ventes, réglages, code secret (seule son empreinte est gardée) ;
  - `hotzi/network` : allumer, éteindre, nom et mot de passe du Wi-Fi, annuler un ticket, autorisations ;
  - `hotzi/network/state` : l'état du Wi-Fi, envoyé à chaque changement (et chaque seconde quand il tourne).
- L'app n'affiche « protégé » que si le Wi-Fi et le proxy tournent vraiment.

## Structure

| Dossier | Rôle |
|---|---|
| `lib/data` | Modèles (forfait, ticket, vente), codes des tickets, accès aux données via le pont |
| `lib/network` | État et commandes du Wi-Fi Hotzi |
| `lib/state` | État de l'app (`AppState`) partagé par tous les écrans |
| `lib/features` | Écrans : bienvenue, code secret, accueil, vente, ticket, tickets, forfaits, Wi-Fi, aide au client |
| `lib/widgets` | Logo animé, boutons, barre de navigation, apparitions |
| `lib/theme` | Couleurs, polices, thème |
| `assets/fonts` | Polices intégrées (licence OFL), pour marcher sans Internet |

## Commandes

```sh
flutter test                 # tests automatiques (données et Wi-Fi simulés)
flutter analyze              # analyse du code
flutter build apk --release  # APK à installer sur le téléphone du vendeur
```

## Signature de l'APK

L'APK de publication est signé avec la clé Hotzi. Une mise à jour ne s'installe par-dessus l'app d'un vendeur que si elle est signée avec **la même clé** : la perdre, c'est obliger chaque vendeur à désinstaller Hotzi et à perdre ses ventes.

- La clé et son mot de passe sont rangés hors du dépôt, dans `hotzi-signature/` à côté du dossier `hotzi` : `hotzi-release.jks` et `key.properties`. **Ce dossier doit être sauvegardé** (clé USB, coffre-fort de mots de passe), jamais mis dans Git.
- Pour construire l'APK sur un autre ordinateur, copier `key.properties` dans `app/android/` et corriger le chemin `storeFile`.
- Sans `key.properties`, l'APK est signé avec la clé de débogage de l'ordinateur et Gradle le signale : à ne jamais donner à un vendeur.

## À savoir

Flutter prévient que la bibliothèque `net` applique encore le plugin Kotlin classique. Ce n'est pas bloquant aujourd'hui ; il faudra la passer au « Kotlin intégré » d'Android quand Flutter l'exigera.
