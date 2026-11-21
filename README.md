# OldBoard — Ordinateur de bord OBD KWP1281 Open-Source (VAG 1995–2004)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Kotlin](https://img.shields.io/badge/Android-Kotlin%20KWP1281-7F52FF?logo=kotlin&logoColor=white)
![Protocol](https://img.shields.io/badge/OBD-KWP1281%20%2F%20K--Line-E1061B)
![License](https://img.shields.io/badge/License-MIT-10B981)

**OldBoard** transforme un smartphone Android en véritable **ordinateur de bord / afficheur de télémétrie OEM** pour les véhicules **Audi, Volkswagen, SEAT et Škoda des années 1995 à 2004** (pré-CAN-Bus, protocole **KWP1281 sur ligne K**) — en particulier les modèles dépourvus d'afficheur FIS/MFA d'origine.

Conçu et calibré sur route à partir d'une **Audi A3 8L 1.6 AKL (1999, Siemens Simos 2.1 `06A906019AM`)**, le projet est ouvert aux forks et aux contributions pour enrichir le support d'autres calculateurs VAG anciens.

---

## ✨ Fonctionnalités

* **Connexion directe USB-OTG (zéro Bluetooth instable, zéro GPS)** : pilote natif Android Kotlin ([`Kwp1281.kt`](android/app/src/main/kotlin/com/oldboard/oldboard/Kwp1281.kt)) avec initialisation 5 bauds, gestion des blocs `0xE7` (triplets) et `0x02`/`0xF4` (4 octets bruts Simos 2.1), reconnexion matérielle FTDI propre et économie de batterie (aucun appel GPS).
* **Détection automatique du véhicule & Thèmes OEM** : lit les références d'identification `0xF6` du combiné (`0x17`) et du calculateur moteur (`0x01`) pour adapter automatiquement la marque (Audi Rouge, VW Bleu Indiglo, SEAT Sport, Škoda Vert OEM), les groupes de mesures et les formules.
* **Télémétrie complète non affichée sur le compteur d'origine** :
  * **Consommation directe** (`L/100 km` en roulant, `L/h` à l'arrêt) calculée via le débitmètre **MAF G70** (essence) ou le débit direct `L/h` / `mg/coup` (TDI), avec détection de la **coupure d'injection en frein moteur (`0.0 L/100`)**.
  * **Autonomie & Réservoir** : lecture de la jauge carburant en litres au démarrage sur le combiné (`0x17`), suivi des litres restants et calibration automatique à chaque plein complet.
  * **Température moteur réelle (culasse G62)** au degré près *(non lissée à 90 °C comme sur l'aiguille d'origine)*, température d'air d'admission (`G42`), tension batterie/alternateur (`V`).
  * **Santé moteur en direct** : temps d'injection (`ms` ou `mg/c`), régulation **Lambda (`G39`)** avec alerte prise d'air / mélange riche, pression **Turbo (`bar`)** sur `1.8T ME7.5` (`Grp 115`) & `1.9 TDI EDC15` (`Grp 11`), ou débit d'air (`g/s`) / papillon (`°`).
  * **Code couleur instantané** : 🔵 **Bleu** sous les cotes constructeur, ⚪/🟢 **Blanc/Vert** normal, 🔴 **Rouge** au-dessus des cotes.
* **Bilan mécanique automatique du trajet (Min / Max)** : enregistre `MAF max`, `Papillon min/max`, `Régime max`, `Eau max`, `Batterie min` et `Lambda min/max`.
* **Diagnostic & Atelier Moteur (avec confirmation)** :
  * Lecture (`0x07`) et effacement (`0x05`) des codes défauts traduits en français.
  * Calibrage du boîtier papillon (`0x28` — **Groupe `098`** sur papillon à câble, **Groupe `060`** sur DBW).
  * Remise à zéro des auto-adaptations moteur (**Canal `00`**, `0x2A`).
  * Explorateur de blocs bruts (`0xE7` & `F4 raw`) et export du rapport diagnostic complet en 1 clic.
* **Mode Simulation intégré** : permet de tester toute l'interface sans être branché à la voiture.

---

## 🚗 Calculateurs & Profils calibrés

| Famille ECU | Moteurs / Modèles | Protocole | Groupes lus | Papillon | Statut |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Siemens Simos 2.1 / 2.4** | `1.6 8V AKL / AEH` (A3 8L, Golf 4, Bora, Leon 1M, Octavia 1U) | `0x02` / `0xF4` | `1, 2, 3, 4, 5, 7` | `098` | ✅ Testé & calibré sur route (`06A906019AM`) |
| **Siemens Simos 3.3 / 3.4** | `1.6 8V APF / AVU / BFQ` (A3 8L Ph2, Golf 4, Leon, Octavia) | `0xE7` | `1, 2, 3, 4, 5` | `060` | 🔧 Calibré Ross-Tech (retours bienvenus) |
| **Bosch Motronic M3.8.3** | `1.8T AGU`, `1.8 20V AGN` (A3 8L, A4 B5, Golf 4) | `0xE7` | `1, 2, 3, 4, 5` | `098` | 🔧 Calibré Ross-Tech (retours bienvenus) |
| **Bosch Motronic ME7.5** | `1.8T AUM / AUQ / ARZ / BAM` (A3, S3, TT, Golf 4 GTI, Leon) | `0xE7` | `1, 2, 3, 4, 5, 115` | `060` | 🔧 Calibré Ross-Tech + Turbo `Grp 115` |
| **Magneti Marelli 4LV/4MV** | `1.4 16V` & `1.6 16V` (Golf 4, Polo, Ibiza, Fabia) | `0xE7` | `1, 2, 3, 4, 5` | `060` | 🔧 Calibré Ross-Tech (retours bienvenus) |
| **Bosch EDC15VM+ / EDC15P** | `1.9 TDI 90 / 110 / 130` (A3, Golf 4, Bora, Leon, Octavia) | `0xE7` | `1, 3, 6, 7, 11, 15` | N/A | 🔧 Calibré Ross-Tech (Turbo `11` + Conso `15`) |
| **Combiné VDO `0x17`** | A3 8L (`8L0919860E`), Golf 4 (`1J0`), Leon (`1M0`), Octavia (`1U0`) | `0xE7` | `2` (Jauge `L`) | N/A | ✅ Testé sur route (`VDO D10`) |

---

## 🔌 Matériel requis (~15 €)

1. Un smartphone **Android** supportant l'USB-OTG.
2. Un **câble OBD-II USB KKL VAG-COM 409.1 équipé d'une puce FTDI (`FT232RL`)** *(boîtier bleu translucide)*.
3. Un adaptateur **USB-A (femelle) vers USB-C (mâle) OTG**.

> ⚠️ Les boîtiers **ELM327 Bluetooth** standards ne sont **pas** compatibles avec les calculateurs KWP1281 purs (comme le Simos 2.1 de 1999).

---

## 🏗️ Architecture du projet

```text
android/app/src/main/kotlin/com/oldboard/oldboard/
├── Kwp1281.kt          # Implémentation bas niveau KWP1281 (init 5 bauds, 0xE7 / 0x02 / 0xF4, DTC, 0x28, 0x2A)
├── KLineManager.kt     # Thread unique de session, reconnexion matérielle FTDI & resynchronisation
└── MainActivity.kt     # Pont Flutter MethodChannel / EventChannel & permissions USB-OTG

lib/
├── models/
│   ├── engine_data.dart       # Rôles de télémétrie moteur & valeurs horodatées
│   └── vehicle_profile.dart   # 9 profils VAG, 6 familles ECU calibrées & auto-détection OBD
├── services/
│   ├── kline_service.dart     # Interface Dart vers le pilote natif Android
│   ├── vag_decoder.dart       # Décodeur universel 0xE7 + décodeur ROM Simos 2.1 0xF4
│   ├── dashboard_controller.dart # Ordinateur de bord (conso MAF/inj/TDI, autonomie, coupure 0x08, Min/Max)
│   ├── settings.dart          # Persistance locale & journaux sauvegardés
│   └── simulator.dart         # Simulateur de conduite intégré
└── ui/
    ├── theme.dart                 # Design OEM mat haute lisibilité (sans glow)
    ├── profile_picker_screen.dart # Sélection de véhicule & emblèmes de marque
    ├── dashboard_screen.dart      # Tableau de bord adaptatif portrait/paysage
    ├── diag_screen.dart           # Codes défaut, atelier moteur, blocs bruts & export rapport
    └── settings_screen.dart       # Paramètres véhicule, injection & options OBD
```

---

## 🛠️ Compiler le projet depuis les sources

Prérequis : **Flutter 3.x**, **JDK 17+**, **Android SDK**.

```bash
git clone https://github.com/supermedmed-hash/OldBoard.git
cd OldBoard
flutter pub get
flutter analyze
flutter build apk --release
```

L'APK optimisé sera généré dans `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🤝 Contribuer & Ajouter un calculateur

Les **forks** et **Pull Requests** sont les bienvenus ! Consultez [`CONTRIBUTING.md`](CONTRIBUTING.md) pour savoir comment :
* Capturer le rapport diagnostic complet de votre véhicule depuis l'écran `DIAGNOSTIC`
* Ajouter un nouveau profil véhicule ou un nouveau décodeur `0xF4` / `0xE7`

---

## ⚠️ Avertissement

OldBoard est un **projet open-source indépendant**, non affilié à **Audi AG**, **Volkswagen AG**, **SEAT S.A.** ou **Škoda Auto a.s.** Les noms de modèles et marques sont mentionnés uniquement à titre de compatibilité technique.
Ne manipulez pas l'application en conduisant. Utilisez les fonctions d'atelier (`Effacer codes`, `Calibrage papillon`, `RAZ Canal 00`) à l'arrêt et sous votre propre responsabilité.
