# Contribuer à OldBoard

Merci de vouloir contribuer à **OldBoard** ! Le projet vise à faire revivre l'ordinateur de bord des véhicules VAG KWP1281 (1995–2004) avec une code-base propre et facile à forker.

## 1. Comment ajouter ou calibrer un calculateur (ECU)

1. Branchez votre câble **USB KKL FTDI** sur votre voiture (contact mis ou moteur tournant au ralenti).
2. Ouvrez l'onglet **`DIAGNOSTIC`** dans OldBoard et appuyez sur **« Copier le rapport complet »**.
3. Le rapport contient :
   * L'identifiant exact du combiné (`0x17`) et du calculateur moteur (`0x01`)
   * Les blocs de mesures bruts (`0xE7` ou `F4 raw: [b0, b1, b2, b3]`)
   * La trace hexadécimale `TX=[...] RX=[...]`
4. Ouvrez une **Issue** avec ce rapport ou proposez directement une **Pull Request** en mettant à jour :
   * [`lib/models/vehicle_profile.dart`](lib/models/vehicle_profile.dart) : ajouter un `VehicleProfile` et son mapping `preferredE7Map` / `discoveryGroups` ainsi que la règle d'auto-détection dans `detectFromIds()`.
   * [`lib/services/vag_decoder.dart`](lib/services/vag_decoder.dart) : si le calculateur utilise le format `0xF4` (4 octets bruts), ajouter ses formules de décodage.

## 2. Règles de développement avant une Pull Request

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

* Gardez la logique bas niveau KWP1281 strictement isolée dans `android/app/src/main/kotlin/com/oldboard/oldboard/`.
* Toute commande d'écriture KWP1281 (`0x05`, `0x28`, `0x2A`) doit **toujours** passer par une boîte de confirmation utilisateur explicite.
* Ne commitez jamais d'`.apk`, d'`.aab` ni de clés de signature (`*.jks`).
