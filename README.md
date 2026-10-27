# Hotzi

Ton téléphone. Ton Wi-Fi. Tes revenus.

Hotzi transforme un smartphone Android en point Wi-Fi payant. Le vendeur vend des tickets ; chaque client a Internet pendant la durée de son ticket, puis il est coupé, sans couper les autres. Pas de routeur, pas de serveur, et la gestion des ventes marche sans Internet.

## Où en est le projet

Version actuelle de l'app vendeur : **0.4.0**.

| Étape | État |
|---|---|
| Design de l'app (écrans, couleurs Violet & Mangue, animations) | Fait |
| Logo « Lever de soleil » | Fait |
| Prototype réseau (`android/`) | Validé en partie sur le TECNO POP 7 : le Wi-Fi Hotzi se crée, les téléphones s'y connectent, le portail et l'activation par code marchent. La coupure individuelle à la fin d'un ticket reste à vérifier |
| App vendeur (`app/`) | Faite : forfaits, vente de tickets avec QR code, partage et impression, historique, code secret protégé |
| Wi-Fi dans l'app vendeur | Branché : allumer / éteindre, nom et mot de passe au choix, clients connectés, couper un client, annuler un ticket, guide « Aider un client » |
| Portail client | Fait : adresse `http://hotzi`, scan du ticket en photo ou saisie du code, temps restant. Le scan est testé dans Chrome sur ordinateur, pas encore sur téléphone |
| Clé de publication | En place : les mises à jour s'installent par-dessus chez les vendeurs |
| Choix de la solution réseau définitive | Proxy en place ; « le vendeur valide le téléphone » reste à étudier (voir plus bas) |
| Tests finaux sur le POP 7 et rapport de compatibilité | En attente des résultats de test |

### Ce que fait le client

1. Il rejoint le Wi-Fi du vendeur (par défaut **DIRECT-hz-Hotzi**, mot de passe **hotzi2026** ; le vendeur peut les changer).
2. La première fois seulement, il règle le proxy de ce Wi-Fi : **192.168.49.1**, port **8282**. L'écran « Aider un client » de l'app montre comment.
3. Il ouvre **`http://hotzi`** dans son navigateur, en tapant bien le `http://`.
4. Il appuie sur « Scanner mon ticket » et prend le QR code en photo, ou il tape le code. Son temps démarre.

Le client n'installe rien. À la fin de son ticket, il est coupé ; les autres clients ne le sont pas.

### Prochaines étapes

1. Tests sur le POP 7 ([protocole](docs/prototype-reseau.md)) : coupure individuelle, redémarrage, panne, écran éteint, scan du ticket, nom du Wi-Fi.
2. Rapport de compatibilité du POP 7, à partir de ces résultats.
3. Tests sur d'autres téléphones : 2 ou 3 modèles côté vendeur, plusieurs versions d'Android et un iPhone côté clients.
4. Essai réel de quelques jours avec un vendeur, surtout pour voir si le réglage du proxy gêne les clients.
5. Selon ce retour, étude de « le vendeur valide le téléphone ».

### La question réseau encore ouverte

Une application Android ordinaire ne peut pas filtrer le partage de connexion du système. Deux solutions sont à l'étude :

- **Proxy (prototype actuel)** : Hotzi crée son propre Wi-Fi et laisse passer chaque client par un proxy qui vérifie son ticket. Ça marche sans droits spéciaux, mais chaque téléphone client doit régler le proxy une fois, et les appels WhatsApp ne passent pas.
- **Le vendeur valide le téléphone** : le client se connecte au partage de connexion normal sans rien régler ; le vendeur l'accepte dans Hotzi et l'associe à son ticket. Meilleure expérience, toutes les applis marchent, mais il faut vérifier que le POP 7 l'autorise (via Shizuku).

## Contenu du dépôt

| Dossier | Rôle |
|---|---|
| [`app`](app/README.md) | Application Flutter du vendeur : forfaits, vente de tickets avec QR code, partage et impression, historique, code secret, Wi-Fi. |
| `android/net` | Bibliothèque réseau en Kotlin, utilisée par l'app : Wi-Fi Direct, proxy d'accès, portail `http://hotzi` avec scan du ticket, règles des tickets et base de données (forfaits, tickets, ventes). |
| `android/banc` | Petite app de test du prototype réseau : démarrer le Wi-Fi, créer des tickets de test, voir qui a Internet. |
| [`docs`](docs/prototype-reseau.md) | Mode d'emploi du réseau Hotzi, protocole de test sur le POP 7 et limites connues. |

## Démarrer

Prérequis : Flutter 3.44 ou plus récent, JDK 17 et le SDK Android (plateforme 36).

**App vendeur**

```sh
cd app
flutter test                 # 21 tests automatiques
flutter build apk --release  # APK : app/build/app/outputs/flutter-apk/app-release.apk
```

Un APK à donner aux vendeurs doit être signé avec la clé Hotzi : `app/android/key.properties` doit être présent. Cette clé ne va jamais dans Git, et il faut la sauvegarder (voir [app/README.md](app/README.md#signature-de-lapk)).

**Bibliothèque réseau et app de test**

```sh
cd android
./gradlew :net:testDebugUnitTest   # 34 tests : tickets, portail, code secret, nom du Wi-Fi, proxy
./gradlew :banc:assembleDebug      # APK : android/banc/build/outputs/apk/debug/banc-debug.apk
```

## Installer sur un téléphone, sans câble

1. Envoie-toi l'APK (WhatsApp, Drive, Bluetooth…) et ouvre-le sur le téléphone.
2. Accepte « installer des applis inconnues » pour l'appli qui ouvre le fichier, puis installe.

**Version 0.4.0 : désinstalle Hotzi une fois avant de l'installer.** L'app est maintenant signée avec sa vraie clé, et Android refuse de la poser par-dessus une version signée avec l'ancienne. Ensuite, les mises à jour s'installeront de nouveau par-dessus.

Seul le téléphone du vendeur installe Hotzi : les téléphones clients n'installent rien. N'installe pas en même temps l'app vendeur et l'app de test réseau : elles se disputeraient le Wi-Fi Direct.

## Principes

- **Jamais de faux état** : l'app n'affiche « protégé » que si le contrôle réseau tourne vraiment. Si Hotzi s'arrête, personne n'a Internet.
- **Tout marche hors ligne** : forfaits, tickets et ventes sont enregistrés sur le téléphone. Les polices sont intégrées à l'app.
- **Un ticket garde son prix** : modifier un forfait ne change pas un ticket déjà vendu.
- **Code secret protégé** : la base ne garde que son empreinte, jamais le code.
- **Aucun serveur ni compte** : tout tourne sur le téléphone du vendeur, y compris le lecteur de QR code du portail.
- **Des codes sans confusion** : 8 caractères, sans 0/O ni 1/I. Le QR code ne contient que le code.
- **Pour tout le monde** : mots simples, gros boutons, animations coupées si le téléphone le demande.
