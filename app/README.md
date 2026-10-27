# Hotzi · app vendeur (Flutter)

L'application du vendeur : forfaits, vente de tickets avec QR code, historique des ventes, code secret et Wi-Fi Hotzi. Le design suit le canvas validé (palette Violet & Mangue, logo « Lever de soleil »).

## Comment elle est construite

- **L'interface** est en Flutter (`lib/`).
- **Le Wi-Fi et les données** sont dans la bibliothèque Kotlin `android/net`, incluse dans le projet Android de l'app. Les données y vivent pour que le service qui coupe les clients les lise même quand l'app est fermée.
- **Le pont** entre les deux est dans `android/app/src/main/kotlin/com/hotzi/hotzi/HotziBridge.kt` :
  - `hotzi/data` : forfaits, tickets, ventes, réglages ;
  - `hotzi/network` : allumer, éteindre, annuler un ticket, autorisations ;
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

## À savoir

Flutter prévient que la bibliothèque `net` applique encore le plugin Kotlin classique. Ce n'est pas bloquant aujourd'hui ; il faudra la passer au « Kotlin intégré » d'Android quand Flutter l'exigera.
