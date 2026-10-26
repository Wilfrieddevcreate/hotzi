# Hotzi

Ton téléphone. Ton Wi-Fi. Tes revenus.

Hotzi transforme un smartphone Android en point Wi-Fi payant. Le vendeur vend des tickets ; chaque client a Internet pendant la durée de son ticket, puis il est coupé, sans couper les autres. Pas de routeur, pas de serveur, et la gestion des ventes marche sans Internet.

## Où en est le projet

| Étape | État |
|---|---|
| Design de l'app (écrans, couleurs Violet & Mangue, animations) | Fait |
| Logo « Lever de soleil » | Fait |
| Prototype réseau (`android/`) | Écrit et testé automatiquement. Sur le TECNO POP 7, le Wi-Fi Hotzi se crée et les téléphones s'y connectent ; le proxy et la coupure individuelle restent à tester |
| App vendeur, partie hors réseau (`app/`) | Faite : forfaits, vente de tickets avec QR code, historique, code secret |
| Choix de la solution réseau définitive | En cours (voir plus bas) |
| Branchement du réseau dans l'app, portail final | À faire après le choix |
| Tests finaux sur le POP 7 et rapport de compatibilité | À faire |

### La question réseau encore ouverte

Une application Android ordinaire ne peut pas filtrer le partage de connexion du système. Deux solutions sont à l'étude :

- **Proxy (prototype actuel)** : Hotzi crée son propre Wi-Fi et laisse passer chaque client par un proxy qui vérifie son ticket. Ça marche sans droits spéciaux, mais chaque téléphone client doit régler le proxy une fois, et les appels WhatsApp ne passent pas.
- **Le vendeur valide le téléphone** : le client se connecte au partage de connexion normal sans rien régler ; le vendeur l'accepte dans Hotzi et l'associe à son ticket. Meilleure expérience, toutes les applis marchent, mais il faut vérifier que le POP 7 l'autorise (via Shizuku).

## Contenu du dépôt

| Dossier | Rôle |
|---|---|
| [`app`](app/README.md) | Application Flutter du vendeur : forfaits, vente de tickets avec QR code, partage et impression, historique, code secret. |
| `android/net` | Bibliothèque réseau en Kotlin : Wi-Fi Direct, proxy d'accès, portail `hotzi.wifi`, règles des tickets. L'app Flutter l'utilisera telle quelle. |
| `android/banc` | Petite app de test du prototype réseau : démarrer le Wi-Fi, créer des tickets de test, voir qui a Internet. |
| [`docs`](docs/prototype-reseau.md) | Mode d'emploi et protocole de test du prototype réseau. |

## Démarrer

Prérequis : Flutter 3.44 ou plus récent, JDK 17 et le SDK Android (plateforme 36).

**App vendeur**

```sh
cd app
flutter test                 # 14 tests automatiques
flutter build apk --release  # APK : app/build/app/outputs/flutter-apk/app-release.apk
```

**Prototype réseau**

```sh
cd android
./gradlew :net:testDebugUnitTest   # 20 tests des règles des tickets
./gradlew :banc:assembleDebug      # APK : android/banc/build/outputs/apk/debug/banc-debug.apk
```

## Installer sur un téléphone, sans câble

1. Envoie-toi l'APK (WhatsApp, Drive, Bluetooth…) et ouvre-le sur le téléphone.
2. Accepte « installer des applis inconnues » pour l'appli qui ouvre le fichier, puis installe.

L'app de test réseau s'installe sur le POP 7 seulement : les téléphones clients n'installent rien.

## Principes

- **Jamais de faux état** : l'app n'affiche « protégé » que si le contrôle réseau tourne vraiment. Si Hotzi s'arrête, personne n'a Internet.
- **Tout marche hors ligne** : forfaits, tickets et ventes sont enregistrés sur le téléphone. Les polices sont intégrées à l'app.
- **Un ticket garde son prix** : modifier un forfait ne change pas un ticket déjà vendu.
- **Des codes sans confusion** : 8 caractères, sans 0/O ni 1/I. Le QR code ne contient que le code.
- **Pour tout le monde** : mots simples, gros boutons, animations coupées si le téléphone le demande.
