# Hotzi · app vendeur (Flutter)

L'application du vendeur : forfaits, vente de tickets avec QR code, historique des ventes, code secret. Le design suit le canvas validé (palette Violet & Mangue, logo « Lever de soleil »).

Le Wi-Fi n'est pas encore relié : il le sera avec la bibliothèque `android/net`, une fois le test réseau validé sur le TECNO POP 7. En attendant, l'app le dit clairement au lieu d'afficher un faux état.

## Structure

| Dossier | Rôle |
|---|---|
| `lib/data` | Modèles (forfait, ticket, vente), codes des tickets, enregistrement local SQLite |
| `lib/state` | État de l'app (`AppState`) partagé par tous les écrans |
| `lib/features` | Écrans : bienvenue, code secret, accueil, vente, ticket, tickets, forfaits, Wi-Fi |
| `lib/widgets` | Logo animé, boutons, barre de navigation, apparitions |
| `lib/theme` | Couleurs, polices, thème |
| `assets/fonts` | Polices intégrées (licence OFL), pour marcher sans Internet |

## Commandes

```sh
flutter test                 # tests automatiques
flutter analyze              # analyse du code
flutter build apk --release  # APK à installer sur le téléphone
```
