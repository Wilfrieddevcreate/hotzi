# Hotzi

Ton téléphone. Ton Wi-Fi. Tes revenus.

Hotzi transforme un smartphone Android en point Wi-Fi payant : le vendeur vend des tickets, chaque client a Internet pendant la durée de son ticket, puis il est coupé, sans couper les autres. Pas de routeur, pas de serveur.

## Où en est le projet

**Étape A : prototype réseau.** Il doit être validé sur le TECNO POP 7 avant de construire l'application complète. Voir [docs/prototype-reseau.md](docs/prototype-reseau.md).

## Contenu du dépôt

| Dossier | Rôle |
|---|---|
| `android/net` | Bibliothèque réseau en Kotlin : Wi-Fi Direct, proxy d'accès, portail `hotzi.wifi`, règles des tickets. L'app Flutter l'utilisera telle quelle. |
| `android/banc` | Petite app de test du prototype : démarrer le Wi-Fi, créer des tickets de test, voir qui a Internet. |
| `docs` | Documentation et protocole de test. |

## Démarrer

Prérequis : JDK 17 et le SDK Android (plateforme 36).

```sh
cd android
./gradlew :net:testDebugUnitTest   # tests automatiques
./gradlew :banc:installDebug       # installe l'app de test sur le téléphone branché
```
