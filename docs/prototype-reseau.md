# Prototype réseau Hotzi

**But :** prouver sur le TECNO POP 7 que Hotzi peut donner Internet à un client avec un ticket, et le lui couper à la fin du ticket sans couper les autres. C'est l'étape A du cahier des charges : tant qu'elle n'est pas validée, la vente de tickets ne l'est pas non plus.

## Comment ça marche

```
Téléphone client ──Wi-Fi « DIRECT-hz-Hotzi »──> POP 7 ──données mobiles──> Internet
                                                  │
                                       proxy Hotzi 192.168.49.1:8282
                                       (vérifie le ticket à chaque connexion)
```

- Le POP 7 crée son propre Wi-Fi en Wi-Fi Direct : **DIRECT-hz-Hotzi**, mot de passe **hotzi2026** (le vendeur peut les changer dans l'app). Ce réseau n'a aucune route vers Internet.
- La seule sortie est le **proxy Hotzi** (`192.168.49.1`, port `8282`). À chaque connexion, il vérifie que le client a un ticket en cours.
- Le **portail** `http://hotzi.wifi` sert à entrer le code. Un client sans ticket qui ouvre une page web en `http://` tombe dessus.
- À la fin d'un ticket, ou s'il est annulé, le proxy **ferme toutes les connexions de ce client** dans la seconde et refuse les nouvelles. Les autres clients ne sont pas touchés.
- **Si Hotzi s'arrête, plus personne n'a Internet.** Il n'existe aucun autre chemin.
- Les tickets et leurs heures de fin sont enregistrés sur le téléphone : un redémarrage ne remet aucun chrono à zéro, et Hotzi se relance tout seul.

## Compiler et installer

Depuis le dossier `android/` :

```sh
./gradlew :net:testDebugUnitTest   # tests automatiques des règles des tickets
./gradlew :banc:installDebug       # installe « Hotzi Banc » sur le téléphone branché en USB
adb logcat -s Hotzi                # suit le journal en direct pendant les tests
```

## Préparer le POP 7 (une seule fois)

1. Activer les **options pour les développeurs** (appuyer 7 fois sur « Numéro de build »), puis le **débogage USB**.
2. **Données mobiles** activées, avec du crédit.
3. **Wi-Fi allumé**, mais **connecté à aucun réseau** : le Wi-Fi Direct a besoin du Wi-Fi, pas d'une connexion.
4. **Localisation activée** : Android 12 l'exige pour le Wi-Fi Direct.
5. Dans Hotzi Banc :
   - accepter la localisation **précise** ;
   - appuyer sur **« Ne pas couper Hotzi »** et accepter.
6. Dans les réglages HiOS (les noms exacts peuvent varier, à vérifier sur le téléphone) :
   - autoriser le **lancement automatique** de Hotzi Banc ;
   - le **verrouiller** dans les applis récentes pour que le nettoyage ne le ferme pas.

## Préparer un téléphone client (une seule fois)

**Android :** Réglages › Wi-Fi › **DIRECT-hz-Hotzi** (mot de passe `hotzi2026`) › appui long sur le réseau › **Modifier** › Options avancées › Proxy : **Manuel** › Nom d'hôte **192.168.49.1** › Port **8282** › Enregistrer.

**iPhone :** Réglages › Wi-Fi › touche (i) à côté du réseau › **Proxy HTTP** › Manuel › Serveur **192.168.49.1** › Port **8282**.

Ouvrir ensuite le navigateur et taper **`http://hotzi.wifi`** en entier, avec le `http://`. Sinon Chrome essaie la version sécurisée et affiche une erreur.

## Tester avec l'app vendeur

Le même réseau est maintenant dans l'app Hotzi (`app/`). On peut faire les tests ci-dessous avec elle au lieu de l'app de test :

- **Démarrer :** onglet **Wi-Fi** › « Allumer le Wi-Fi ».
- **Créer un ticket :** onglet **Vendre**. Le plus court des forfaits de démonstration dure 30 minutes. Pour le test 6, crée un forfait de 2 minutes dans l'onglet **Forfaits**.
- **Voir qui a Internet, couper un client :** onglet **Wi-Fi**, liste « téléphones avec Internet ».
- **Annuler un ticket :** onglet **Tickets** › le ticket › « Annuler ce ticket ».

Désinstalle d'abord l'app de test réseau (Hotzi Banc) : les deux apps se disputeraient le Wi-Fi Direct.

## Protocole de test

Il faut le POP 7 et deux téléphones clients, A et B, réglés comme ci-dessus. Les numéros entre parenthèses renvoient aux tests du cahier des charges.

| # | Test | Comment faire | Résultat attendu |
|---|---|---|---|
| 1 | Démarrage | Appuyer sur « Démarrer le Wi-Fi Hotzi » | En 10 s environ : « CONTRÔLE ACTIF », et la notification Hotzi |
| 2 | Sans ticket (critère 4) | A ouvre `http://hotzi.wifi`, puis essaie Chrome, WhatsApp, YouTube | La page Hotzi s'affiche, aucune appli n'a Internet |
| 3 | Code faux (test 3) | A entre `AAAA-AAAA` | « Ce code ne marche pas » |
| 4 | Activation (test 2) | Créer un ticket de 5 min, A entre son code | « Tu es connecté », A navigue, le banc affiche « En cours » avec l'adresse de A |
| 5 | Réutilisation (test 5) | B entre le même code | « Ce ticket est déjà utilisé », B n'a pas Internet |
| 6 | Expiration individuelle (tests 4 et 8) | Ticket de 2 min pour B, A garde son ticket de 5 min. Les deux regardent une vidéo | Au bout de 2 min, B est coupé et A continue |
| 7 | Annulation | « Annuler » sur le ticket de A | A est coupé tout de suite |
| 8 | Panne du contrôle (test 7) | Paramètres › Applis › Hotzi Banc › **Forcer l'arrêt** | Plus personne n'a Internet, le Wi-Fi Hotzi disparaît |
| 9 | Redémarrage (test 6) | Ticket en cours sur A, redémarrer le POP 7 | Hotzi se relance seul. Le ticket garde son heure de fin. Si A n'a plus Internet, il entre de nouveau son code |
| 10 | Hors ligne (test 9) | Couper les données mobiles du POP 7 | Le banc l'indique, les clients n'ont plus Internet, le portail reste accessible |
| 11 | Écran éteint | Écran du POP 7 éteint pendant 2 h, A utilise Internet de temps en temps | Le Wi-Fi tient, A garde Internet |
| 12 | Applis | Avec un ticket en cours, A essaie Chrome, WhatsApp (messages, photo, appel), YouTube, Facebook, TikTok, Play Store | À noter appli par appli : les appels ne marcheront pas |
| 13 | Débit | Ouvrir `fast.com` sur 1 client, puis sur 3 clients en même temps | À noter |
| 14 | Nombre de clients | Connecter des téléphones jusqu'au refus | À noter |
| 15 | Alerte Android | Sur un client sans ticket, regarder si Android affiche « Se connecter au réseau » | À noter (piste pour ouvrir le portail tout seul) |

## Limites connues du prototype

- Le client doit **régler le proxy une fois** par téléphone.
- Seul le trafic qui passe par le proxy marche : la navigation et les applis qui respectent le proxy. **Pas d'appels WhatsApp** ni de jeux en ligne.
- Les clients sont reconnus par leur **adresse IP**. Un utilisateur averti pourrait prendre l'adresse d'un autre.
- Un ticket en cours peut passer sur une nouvelle adresse si l'ancienne n'a rien fait depuis 3 minutes, par exemple après une reconnexion. Il ne marche jamais sur deux téléphones en même temps.
- Le nom et le mot de passe du Wi-Fi se changent dans l'app vendeur (onglet Wi-Fi). Android impose que le nom commence par `DIRECT-hz-`. Après un changement, chaque téléphone client doit rejoindre le nouveau réseau et régler de nouveau le proxy. L'app de test garde `DIRECT-hz-Hotzi` / `hotzi2026`.
- `.wifi` est une vraie extension de nom de domaine. Le proxy ne laisse jamais `hotzi.wifi` partir sur Internet, mais pour l'app finale il faudra soit acheter `hotzi.wifi`, soit choisir un nom qui ne peut pas exister sur Internet.
- Les tickets sont enregistrés dans la même base SQLite que l'app vendeur (`hotzi.db`).

## En cas de problème

- **« Impossible de créer le Wi-Fi Hotzi (Wi-Fi occupé) » :** éteindre puis rallumer le Wi-Fi. Hotzi réessaie tout seul toutes les 10 s.
- **Le réseau DIRECT-hz-Hotzi n'apparaît pas :** vérifier que le Wi-Fi et la localisation sont allumés sur le POP 7.
- **Le client est connecté au Wi-Fi mais rien ne charge :** vérifier le proxy saisi (192.168.49.1, port 8282).
- Pour toute anomalie, envoyer le journal : `adb logcat -s Hotzi > hotzi-log.txt`.

## Fiche de résultats

| # | OK / pas OK | Remarques |
|---|---|---|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |
| 6 | | |
| 7 | | |
| 8 | | |
| 9 | | |
| 10 | | |
| 11 | | |
| 12 | | |
| 13 | | |
| 14 | | |
| 15 | | |
