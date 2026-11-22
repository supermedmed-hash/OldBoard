import 'package:flutter/material.dart';

import 'engine_data.dart';

enum VehicleBrand { audi, vw, seat, skoda }

enum FuelType { petrol, diesel }

enum EcuFamily {
  simos21, // Siemens Simos 2.1/2.4 (1.6 8V AKL/AEH, 0xF4, cable, Grp 098)
  simos3, // Siemens Simos 3.3/3.4 (1.6 8V APF/AVU/BFQ, 0xE7, DBW, Grp 060)
  motronicM38, // Bosch Motronic M3.8.2/M3.8.3 (1.8T AGU / 1.8 AGN, 0xE7, cable, Grp 098)
  motronicMe75, // Bosch Motronic ME7.5 (1.8T AUM/AUQ/ARZ/BAM, 0xE7, DBW, Grp 060 + 115 Turbo)
  marelli4lv, // Magneti Marelli 4LV/4MV (1.4/1.6 16V AHW/AKQ/AXP/BCA/AZD/BCB, 0xE7, DBW, Grp 060)
  edc15Tdi, // Bosch EDC15VM+/EDC15P (1.9 TDI ALH/AGR/AHF/ASV/ASZ/ARL, 0xE7, Grp 1/3/6/7/11/15)
}

class VehicleProfile {
  final String id;
  final VehicleBrand brand;
  final EcuFamily ecuFamily;
  final String name;
  final String subtitle;
  final String headerShort;
  final FuelType fuelType;
  final bool hasTurbo;
  final double tankCapacity;
  final double injectorFlow;
  final double injectorDeadTime;
  final int shiftRpm;
  final Color accent;
  final double consoMin;
  final double consoMax;
  final double idleLphMin;
  final double idleLphMax;
  final List<int> discoveryGroups;
  final int? throttleBasicGroup; // 98 (cable), 60 (DBW), null (TDI Diesel)
  final Map<EngineRole, String> preferredE7Map;

  const VehicleProfile({
    required this.id,
    required this.brand,
    required this.ecuFamily,
    required this.name,
    required this.subtitle,
    required this.headerShort,
    required this.fuelType,
    this.hasTurbo = false,
    required this.tankCapacity,
    required this.injectorFlow,
    required this.injectorDeadTime,
    required this.shiftRpm,
    required this.accent,
    required this.consoMin,
    required this.consoMax,
    required this.idleLphMin,
    required this.idleLphMax,
    required this.discoveryGroups,
    required this.throttleBasicGroup,
    this.preferredE7Map = const {},
  });

  bool get isDiesel => fuelType == FuelType.diesel;

  String get ecuLabel => switch (ecuFamily) {
        EcuFamily.simos21 => 'Simos 2.1 (0xF4)',
        EcuFamily.simos3 => 'Simos 3 (0xE7)',
        EcuFamily.motronicM38 => 'Motronic M3.8.3',
        EcuFamily.motronicMe75 => 'Motronic ME7.5',
        EcuFamily.marelli4lv => 'Marelli 4LV/4MV',
        EcuFamily.edc15Tdi => 'Bosch EDC15 TDI',
      };

  // Mappings Ross-Tech VCDS verifies par famille de calculateur 0xE7
  static const Map<EngineRole, String> _me75Map = {
    EngineRole.rpm: '1:0',
    EngineRole.coolant: '1:1',
    EngineRole.lambda: '1:2',
    EngineRole.load: '2:1',
    EngineRole.injection: '2:2',
    EngineRole.maf: '2:3',
    EngineRole.throttle: '3:2',
    EngineRole.battery: '4:1',
    EngineRole.intakeAir: '4:3',
    EngineRole.speed: '5:2',
    EngineRole.map: '115:3', // Boost reel (mbar absolus)
  };

  static const Map<EngineRole, String> _m38Map = {
    EngineRole.rpm: '1:0',
    EngineRole.coolant: '1:1',
    EngineRole.lambda: '1:2',
    EngineRole.load: '2:1',
    EngineRole.injection: '2:2',
    EngineRole.maf: '2:3',
    EngineRole.throttle: '3:2',
    EngineRole.battery: '4:1',
    EngineRole.intakeAir: '4:3',
    EngineRole.speed: '5:2',
  };

  static const Map<EngineRole, String> _simos3Map = {
    EngineRole.rpm: '1:0',
    EngineRole.coolant: '1:1',
    EngineRole.lambda: '1:2',
    EngineRole.load: '2:1',
    EngineRole.maf: '3:1',
    EngineRole.throttle: '3:2',
    EngineRole.battery: '4:1',
    EngineRole.intakeAir: '4:3',
    EngineRole.speed: '5:2',
  };

  static const Map<EngineRole, String> _marelli4lvMap = {
    EngineRole.rpm: '1:0',
    EngineRole.coolant: '1:1',
    EngineRole.lambda: '1:2',
    EngineRole.injection: '2:1',
    EngineRole.map: '3:1',
    EngineRole.throttle: '3:2',
    EngineRole.battery: '4:1',
    EngineRole.intakeAir: '4:3',
    EngineRole.speed: '5:2',
  };

  static const Map<EngineRole, String> _edc15TdiMap = {
    EngineRole.rpm: '1:0',
    EngineRole.fuelMg: '15:1', // Quantite injectee reelle (mg/coup)
    EngineRole.coolant: '1:3',
    EngineRole.maf: '3:2', // MAF reel (mg/coup ou g/s)
    EngineRole.speed: '6:0', // Vitesse vehicule EDC15 (Grp 006 champ 1)
    EngineRole.intakeAir: '7:2', // Temp. air admission (Grp 007 champ 3)
    EngineRole.map: '11:2', // Pression turbo reelle (Grp 011 champ 3, mbar absolus)
    EngineRole.fuelLph: '15:2', // Conso directe L/h calculee par l'EDC15 (Grp 015 champ 3)
    EngineRole.throttle: '15:3', // Position pedale accelerateur % (Grp 015 champ 4)
  };

  static const List<VehicleProfile> all = [
    VehicleProfile(
      id: 'audi_a3_8l_akl',
      brand: VehicleBrand.audi,
      ecuFamily: EcuFamily.simos21,
      name: 'Audi A3 8L — 1.6 AKL / AEH',
      subtitle: '1996–2000 • Simos 2.1 (0xF4 calibré) • Grp 098 • 55 L',
      headerShort: 'A3 8L 1.6',
      fuelType: FuelType.petrol,
      tankCapacity: 55,
      injectorFlow: 205,
      injectorDeadTime: 0.85,
      shiftRpm: 5800,
      accent: Color(0xFFFF2438),
      consoMin: 3.5,
      consoMax: 11.5,
      idleLphMin: 0.6,
      idleLphMax: 1.6,
      discoveryGroups: [1, 2, 3, 4, 5, 7],
      throttleBasicGroup: 98,
    ),
    VehicleProfile(
      id: 'audi_a3_8l_simos3',
      brand: VehicleBrand.audi,
      ecuFamily: EcuFamily.simos3,
      name: 'Audi A3 8L Ph2 — 1.6 APF / AVU / BFQ',
      subtitle: '2000–2003 • Simos 3 (0xE7 DBW) • Grp 060 • 55 L',
      headerShort: 'A3 8L 1.6 Ph2',
      fuelType: FuelType.petrol,
      tankCapacity: 55,
      injectorFlow: 205,
      injectorDeadTime: 0.85,
      shiftRpm: 5800,
      accent: Color(0xFFFF2438),
      consoMin: 3.5,
      consoMax: 11.5,
      idleLphMin: 0.6,
      idleLphMax: 1.5,
      discoveryGroups: [1, 2, 3, 4, 5],
      throttleBasicGroup: 60,
      preferredE7Map: _simos3Map,
    ),
    VehicleProfile(
      id: 'audi_18t_m38',
      brand: VehicleBrand.audi,
      ecuFamily: EcuFamily.motronicM38,
      name: 'Audi A3 8L / A4 B5 — 1.8T AGU / 1.8 AGN',
      subtitle: '1996–2000 • Bosch M3.8.3 (câble) • Grp 098 • 55 L',
      headerShort: 'AUDI 1.8T AGU',
      fuelType: FuelType.petrol,
      hasTurbo: true,
      tankCapacity: 55,
      injectorFlow: 260, // Bosch 0280150464 (06A906031) : ~258-260 cc/min @ 3 bar
      injectorDeadTime: 0.85,
      shiftRpm: 6200,
      accent: Color(0xFFE1061B),
      consoMin: 4.5,
      consoMax: 14.0,
      idleLphMin: 0.7,
      idleLphMax: 1.8,
      discoveryGroups: [1, 2, 3, 4, 5],
      throttleBasicGroup: 98,
      preferredE7Map: _m38Map,
    ),
    VehicleProfile(
      id: 'audi_18t_me75',
      brand: VehicleBrand.audi,
      ecuFamily: EcuFamily.motronicMe75,
      name: 'Audi A3 / S3 / TT — 1.8T AUM / AUQ / BAM',
      subtitle: '2000–2004 • Bosch ME7.5 (Turbo Grp 115) • Grp 060',
      headerShort: 'AUDI 1.8T ME7',
      fuelType: FuelType.petrol,
      hasTurbo: true,
      tankCapacity: 55,
      injectorFlow: 317,
      injectorDeadTime: 0.85,
      shiftRpm: 6400,
      accent: Color(0xFFE1061B),
      consoMin: 4.5,
      consoMax: 15.0,
      idleLphMin: 0.7,
      idleLphMax: 1.8,
      discoveryGroups: [1, 2, 3, 4, 5, 115],
      throttleBasicGroup: 60,
      preferredE7Map: _me75Map,
    ),
    VehicleProfile(
      id: 'vw_golf4_petrol',
      brand: VehicleBrand.vw,
      ecuFamily: EcuFamily.simos21,
      name: 'VW Golf 4 / Bora — 1.6 AKL / AEH / APF',
      subtitle: '1997–2003 • Simos 2.1 / 3 • Thème Bleu Indiglo VW',
      headerShort: 'GOLF 4 1.6',
      fuelType: FuelType.petrol,
      tankCapacity: 55,
      injectorFlow: 205,
      injectorDeadTime: 0.85,
      shiftRpm: 5800,
      accent: Color(0xFF2563EB),
      consoMin: 3.5,
      consoMax: 11.5,
      idleLphMin: 0.6,
      idleLphMax: 1.6,
      discoveryGroups: [1, 2, 3, 4, 5, 7],
      throttleBasicGroup: 98,
      preferredE7Map: _simos3Map,
    ),
    VehicleProfile(
      id: 'vw_14_16v_marelli',
      brand: VehicleBrand.vw,
      ecuFamily: EcuFamily.marelli4lv,
      name: 'VW Golf 4 / Polo — 1.4 & 1.6 16V',
      subtitle: '1998–2004 • Marelli 4LV/4MV (MAP) • Grp 060 • Bleu VW',
      headerShort: 'VW 16V',
      fuelType: FuelType.petrol,
      tankCapacity: 55,
      injectorFlow: 150,
      injectorDeadTime: 0.85,
      shiftRpm: 5800,
      accent: Color(0xFF2563EB),
      consoMin: 3.2,
      consoMax: 10.5,
      idleLphMin: 0.5,
      idleLphMax: 1.3,
      discoveryGroups: [1, 2, 3, 4, 5],
      throttleBasicGroup: 60,
      preferredE7Map: _marelli4lvMap,
    ),
    VehicleProfile(
      id: 'vag_19_tdi',
      brand: VehicleBrand.vw,
      ecuFamily: EcuFamily.edc15Tdi,
      name: 'VW / Audi / Seat — 1.9 TDI (90–130)',
      subtitle: '1997–2004 • Bosch EDC15 (Turbo Grp 11 + Conso Grp 15)',
      headerShort: '1.9 TDI',
      fuelType: FuelType.diesel,
      hasTurbo: true,
      tankCapacity: 55,
      injectorFlow: 205,
      injectorDeadTime: 0.0,
      shiftRpm: 4200,
      accent: Color(0xFF0EA5E9),
      consoMin: 2.8,
      consoMax: 9.0,
      idleLphMin: 0.3,
      idleLphMax: 1.0,
      discoveryGroups: [1, 3, 6, 7, 11, 15],
      throttleBasicGroup: null,
      preferredE7Map: _edc15TdiMap,
    ),
    VehicleProfile(
      id: 'seat_leon_1m',
      brand: VehicleBrand.seat,
      ecuFamily: EcuFamily.motronicMe75,
      name: 'SEAT Leon 1M / Toledo — 1.6 / 1.8T',
      subtitle: '1999–2004 • Simos / ME7.5 (Turbo 115) • SEAT Sport',
      headerShort: 'LEON 1M',
      fuelType: FuelType.petrol,
      hasTurbo: true,
      tankCapacity: 55,
      injectorFlow: 205,
      injectorDeadTime: 0.85,
      shiftRpm: 6000,
      accent: Color(0xFFF97316),
      consoMin: 3.5,
      consoMax: 13.0,
      idleLphMin: 0.6,
      idleLphMax: 1.6,
      discoveryGroups: [1, 2, 3, 4, 5, 7, 115],
      throttleBasicGroup: 60,
      preferredE7Map: _me75Map,
    ),
    VehicleProfile(
      id: 'skoda_octavia_1u',
      brand: VehicleBrand.skoda,
      ecuFamily: EcuFamily.simos21,
      name: 'Škoda Octavia 1U / Fabia — 1.6 / 1.8T',
      subtitle: '1997–2004 • Simos / ME7.5 • Thème Vert Škoda OEM',
      headerShort: 'OCTAVIA 1U',
      fuelType: FuelType.petrol,
      tankCapacity: 55,
      injectorFlow: 205,
      injectorDeadTime: 0.85,
      shiftRpm: 5800,
      accent: Color(0xFF10B981),
      consoMin: 3.5,
      consoMax: 11.5,
      idleLphMin: 0.6,
      idleLphMax: 1.6,
      discoveryGroups: [1, 2, 3, 4, 5, 7],
      throttleBasicGroup: 98,
      preferredE7Map: _me75Map,
    ),
  ];

  static VehicleProfile byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);

  /// Detecte automatiquement le profil (marque + famille de calculateur) a partir des chaines
  /// d'identification KWP1281 (0xF6) du combine d'instruments (0x17) et/ou du moteur (0x01).
  static VehicleProfile? detectFromIds({String? clusterId, String? ecuId}) {
    final c = (clusterId ?? '').toUpperCase().replaceAll(' ', '');
    final e = (ecuId ?? '').toUpperCase().replaceAll(' ', '');
    if (c.isEmpty && e.isEmpty) return null;

    // 1. Identification de la marque via la reference du combine (0x17) ou du moteur (0x01)
    VehicleBrand? brand;
    if (c.contains('8L0') ||
        c.contains('L0919') ||
        c.contains('L0920') ||
        c.contains('8D0') ||
        c.contains('8N0') ||
        c.contains('4B0') ||
        e.contains('8N0') ||
        e.contains('8D0') ||
        e.contains('8L0') ||
        e.contains('4B0')) {
      brand = VehicleBrand.audi;
    } else if (c.contains('1M0') || c.contains('6K0') || c.contains('6L0') || c.contains('SEAT')) {
      brand = VehicleBrand.seat;
    } else if (c.contains('1U0') || c.contains('6Y0') || c.contains('SKODA')) {
      brand = VehicleBrand.skoda;
    } else if (c.contains('1J0') || c.contains('1J5') || c.contains('3B0') || c.contains('6N0') || c.contains('6N2')) {
      brand = VehicleBrand.vw;
    }

    // 2. Identification de la famille de calculateur moteur (0x01)
    if (e.isNotEmpty) {
      // Bosch EDC15 (1.9 TDI)
      if (e.contains('EDC') || e.contains('TDI') || e.contains('038906012') || e.contains('038906019') || e.contains('038906018')) {
        return byId('vag_19_tdi');
      }
      // Magneti Marelli 4LV / 4MV (1.4 / 1.6 16V)
      if (e.contains('MARELLI') || e.contains('4LV') || e.contains('4MV') || e.contains('036906034') || e.contains('1.4L')) {
        return byId('vw_14_16v_marelli');
      }
      // Bosch Motronic ME7.5 (1.8T DBW : 06A906032 / 8N0906018 / ME7)
      if (e.contains('ME7') || e.contains('06A906032') || e.contains('8N0906018') || e.contains('4B0906018')) {
        if (brand == VehicleBrand.seat) return byId('seat_leon_1m');
        if (brand == VehicleBrand.skoda) return byId('skoda_octavia_1u');
        return byId('audi_18t_me75');
      }
      // Bosch Motronic M3.8.3 (1.8T AGU / 1.8 AGN cable : 06A906018 / 8D0907557 / MOTR)
      if (e.contains('06A906018') || e.contains('8D0907557') || e.contains('1.8L') || e.contains('M3.8') || e.contains('MOTR')) {
        return byId('audi_18t_m38');
      }
      // Siemens Simos 3 (1.6 APF/AVU/BFQ : 06A906033 / SIMOS3)
      if (e.contains('SIMOS3') || e.contains('06A906033')) {
        if (brand == VehicleBrand.vw) return byId('vw_golf4_petrol');
        if (brand == VehicleBrand.seat) return byId('seat_leon_1m');
        if (brand == VehicleBrand.skoda) return byId('skoda_octavia_1u');
        return byId('audi_a3_8l_simos3');
      }
      // Siemens Simos 2.1/2.4 (1.6 AKL/AEH : 06A906019 / SIMOS)
      if (e.contains('06A906019') || e.contains('SIMOS')) {
        if (brand == VehicleBrand.vw) return byId('vw_golf4_petrol');
        if (brand == VehicleBrand.seat) return byId('seat_leon_1m');
        if (brand == VehicleBrand.skoda) return byId('skoda_octavia_1u');
        return byId('audi_a3_8l_akl');
      }
    }

    // 3. Fallback si seul le combine (0x17) a ete identifie pour l'instant
    if (brand != null) {
      return switch (brand) {
        VehicleBrand.audi => byId('audi_a3_8l_akl'),
        VehicleBrand.vw => byId('vw_golf4_petrol'),
        VehicleBrand.seat => byId('seat_leon_1m'),
        VehicleBrand.skoda => byId('skoda_octavia_1u'),
      };
    }
    return null;
  }
}
