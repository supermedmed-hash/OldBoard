import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_layout.dart';
import '../models/vehicle_profile.dart';

/// Reglages + memoires persistantes (profil vehicule, trajet, carburant restant, journal diagnostic...).
class AppSettings extends ChangeNotifier {
  SharedPreferences? _p;

  // --- profil vehicule & theme OEM
  String profileId = VehicleProfile.all.first.id;
  bool profileSelected = false;

  VehicleProfile get profile => VehicleProfile.byId(profileId);

  // --- vehicule
  double tankCapacity = 55; // A3 8L : 55 L
  double injectorFlow = 205; // cc/min (calibre pour Simos 2.1 1.6 AKL)
  double injectorDeadTime = 0.85; // ms (temps mort injecteurs Bosch EV6)
  double calibration = 1.0; // facteur de correction conso
  int shiftRpm = 5800;
  int cylinders = 4;

  // --- options
  bool readClusterFuel = true;
  bool autoConnect = true;
  bool autoDetectVehicle = true;
  bool autoCheckUpdates = true;
  String ignoredUpdateTag = '';

  // --- memoires
  double fuelRemaining = 40; // L
  double longTermL100 = 7.5; // conso moyenne long terme
  double tripKm = 0, tripFuel = 0, tripSeconds = 0;
  double fillKm = 0, fillFuel = 0; // depuis le dernier plein complet

  // --- bilan mecanique du trajet (Min / Max)
  double maxRpm = 0;
  double maxMaf = 0;
  double minThrottle = -1; // -1 = pas encore mesure
  double maxThrottle = 0;
  double maxCoolant = 0;
  double minBattery = 0;
  double minLambda = 0;
  double maxLambda = 0;

  /// Affectations manuelles : role -> "groupe:index"
  Map<String, String> roleOverrides = {};

  /// Emplacements personnalisés du tableau de bord (2 grandes cartes + 6 tuiles).
  List<HeroSlotType> heroSlots = List<HeroSlotType>.from(DashboardPreset.defaultHeroes);
  List<TileSlotType> tileSlots = List<TileSlotType>.from(DashboardPreset.defaultTiles);

  /// Dernier journal de diagnostic enregistre automatiquement
  List<String> savedLogs = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
    profileId = p.getString('profileId') ?? profileId;
    profileSelected = p.getBool('profileSelected') ?? false;
    tankCapacity = p.getDouble('tankCapacity') ?? tankCapacity;
    final savedFlow = p.getDouble('injectorFlow');
    // Migration automatique de l'ancienne valeur par defaut (160) vers le calibrage Simos 2.1 AKL (205)
    if (savedFlow == null || (savedFlow - 160.0).abs() < 0.1) {
      injectorFlow = 205.0;
      await p.setDouble('injectorFlow', injectorFlow);
    } else {
      injectorFlow = savedFlow;
    }
    final savedDead = p.getDouble('injectorDeadTime');
    if (savedDead == null || savedDead == 0.0) {
      injectorDeadTime = 0.85;
      await p.setDouble('injectorDeadTime', injectorDeadTime);
    } else {
      injectorDeadTime = savedDead;
    }
    calibration = p.getDouble('calibration') ?? calibration;
    shiftRpm = p.getInt('shiftRpm') ?? shiftRpm;
    readClusterFuel = p.getBool('readClusterFuel') ?? readClusterFuel;
    autoConnect = p.getBool('autoConnect') ?? autoConnect;
    autoDetectVehicle = p.getBool('autoDetectVehicle') ?? autoDetectVehicle;
    autoCheckUpdates = p.getBool('autoCheckUpdates') ?? autoCheckUpdates;
    ignoredUpdateTag = p.getString('ignoredUpdateTag') ?? ignoredUpdateTag;
    fuelRemaining = p.getDouble('fuelRemaining') ?? fuelRemaining;
    longTermL100 = p.getDouble('longTermL100') ?? longTermL100;
    tripKm = p.getDouble('tripKm') ?? 0;
    tripFuel = p.getDouble('tripFuel') ?? 0;
    tripSeconds = p.getDouble('tripSeconds') ?? 0;
    fillKm = p.getDouble('fillKm') ?? 0;
    fillFuel = p.getDouble('fillFuel') ?? 0;
    maxRpm = p.getDouble('maxRpm') ?? 0;
    maxMaf = p.getDouble('maxMaf') ?? 0;
    minThrottle = p.getDouble('minThrottle') ?? -1;
    maxThrottle = p.getDouble('maxThrottle') ?? 0;
    maxCoolant = p.getDouble('maxCoolant') ?? 0;
    minBattery = p.getDouble('minBattery') ?? 0;
    minLambda = p.getDouble('minLambda') ?? 0;
    maxLambda = p.getDouble('maxLambda') ?? 0;
    savedLogs = p.getStringList('savedLogs') ?? [];
    final ro = p.getString('roleOverrides');
    if (ro != null) {
      roleOverrides = Map<String, String>.from(jsonDecode(ro) as Map);
    }
    final savedHeroes = p.getStringList('heroSlots');
    if (savedHeroes != null && savedHeroes.length == 2) {
      heroSlots = [
        heroSlotFromName(savedHeroes[0], DashboardPreset.defaultHeroes[0]),
        heroSlotFromName(savedHeroes[1], DashboardPreset.defaultHeroes[1]),
      ];
    }
    final savedTiles = p.getStringList('tileSlots');
    if (savedTiles != null && savedTiles.length == 6) {
      tileSlots = [
        for (var i = 0; i < 6; i++) tileSlotFromName(savedTiles[i], DashboardPreset.defaultTiles[i]),
      ];
    }
    notifyListeners();
  }

  Future<void> save() async {
    final p = _p ?? await SharedPreferences.getInstance();
    _p = p;
    await p.setString('profileId', profileId);
    await p.setBool('profileSelected', profileSelected);
    await p.setDouble('tankCapacity', tankCapacity);
    await p.setDouble('injectorFlow', injectorFlow);
    await p.setDouble('injectorDeadTime', injectorDeadTime);
    await p.setDouble('calibration', calibration);
    await p.setInt('shiftRpm', shiftRpm);
    await p.setBool('readClusterFuel', readClusterFuel);
    await p.setBool('autoConnect', autoConnect);
    await p.setBool('autoDetectVehicle', autoDetectVehicle);
    await p.setBool('autoCheckUpdates', autoCheckUpdates);
    await p.setString('ignoredUpdateTag', ignoredUpdateTag);
    await saveMemories();
    await p.setString('roleOverrides', jsonEncode(roleOverrides));
    await p.setStringList('heroSlots', heroSlots.map((e) => e.name).toList());
    await p.setStringList('tileSlots', tileSlots.map((e) => e.name).toList());
    notifyListeners();
  }

  void setHeroSlot(int index, HeroSlotType type) {
    if (index < 0 || index >= heroSlots.length) return;
    heroSlots[index] = type;
    changed();
  }

  void setTileSlot(int index, TileSlotType type) {
    if (index < 0 || index >= tileSlots.length) return;
    tileSlots[index] = type;
    changed();
  }

  void applyDashboardPreset(DashboardPreset preset) {
    heroSlots = List<HeroSlotType>.from(preset.heroes);
    tileSlots = List<TileSlotType>.from(preset.tiles);
    changed();
  }

  Future<void> saveMemories() async {
    final p = _p ?? await SharedPreferences.getInstance();
    _p = p;
    await p.setDouble('fuelRemaining', fuelRemaining);
    await p.setDouble('longTermL100', longTermL100);
    await p.setDouble('tripKm', tripKm);
    await p.setDouble('tripFuel', tripFuel);
    await p.setDouble('tripSeconds', tripSeconds);
    await p.setDouble('fillKm', fillKm);
    await p.setDouble('fillFuel', fillFuel);
    await p.setDouble('maxRpm', maxRpm);
    await p.setDouble('maxMaf', maxMaf);
    await p.setDouble('minThrottle', minThrottle);
    await p.setDouble('maxThrottle', maxThrottle);
    await p.setDouble('maxCoolant', maxCoolant);
    await p.setDouble('minBattery', minBattery);
    await p.setDouble('minLambda', minLambda);
    await p.setDouble('maxLambda', maxLambda);
  }

  Future<void> saveLogs(List<String> logs) async {
    savedLogs = List<String>.from(logs);
    final p = _p ?? await SharedPreferences.getInstance();
    _p = p;
    await p.setStringList('savedLogs', savedLogs);
  }

  void applyProfile(VehicleProfile prof) {
    profileId = prof.id;
    profileSelected = true;
    tankCapacity = prof.tankCapacity;
    injectorFlow = prof.injectorFlow;
    injectorDeadTime = prof.injectorDeadTime;
    shiftRpm = prof.shiftRpm;
    if (fuelRemaining > tankCapacity) fuelRemaining = tankCapacity;
    changed();
  }

  void changed() {
    notifyListeners();
    save();
  }
}
