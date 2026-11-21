/// Grandes cartes disponibles (2 emplacements en haut du tableau de bord).
enum HeroSlotType {
  conso,
  range,
  speed,
  rpm,
}

extension HeroSlotInfo on HeroSlotType {
  String get label => switch (this) {
        HeroSlotType.conso => 'Consommation',
        HeroSlotType.range => 'Autonomie & Réservoir',
        HeroSlotType.speed => 'Vitesse (OBD)',
        HeroSlotType.rpm => 'Régime moteur (RPM)',
      };

  String get subtitle => switch (this) {
        HeroSlotType.conso => 'L/100 ou L/h + moyenne trajet & débit direct',
        HeroSlotType.range => 'Kilomètres restants + jauge réservoir',
        HeroSlotType.speed => 'Vitesse réelle calculateur (km/h) + moy. trajet',
        HeroSlotType.rpm => 'Compte-tours numérique (tr/min) + barre rupteur',
      };
}

/// Tuiles capteurs disponibles (6 emplacements en grille 2×3).
enum TileSlotType {
  coolant,
  intakeAir,
  battery,
  injection,
  lambda,
  autoAir, // Comportement adaptatif d'origine : Turbo (1.8T/TDI) > Collecteur > MAF > Papillon
  rpm,
  speed,
  maf,
  throttle,
  load,
  boost,
  lph,
  avgSpeed,
  oilTemp,
}

extension TileSlotInfo on TileSlotType {
  String get label => switch (this) {
        TileSlotType.coolant => 'Temp. moteur (G62)',
        TileSlotType.intakeAir => 'Air admission (G42)',
        TileSlotType.battery => 'Tension batterie',
        TileSlotType.injection => 'Injection (ms / mg)',
        TileSlotType.lambda => 'Régulation Lambda (G39)',
        TileSlotType.autoAir => 'Auto (Turbo / MAF / Papillon)',
        TileSlotType.rpm => 'Régime moteur (RPM)',
        TileSlotType.speed => 'Vitesse calculateur (km/h)',
        TileSlotType.maf => 'Débit d\'air (MAF G70)',
        TileSlotType.throttle => 'Angle papillon / Pédale',
        TileSlotType.load => 'Charge moteur (%)',
        TileSlotType.boost => 'Turbo / Collecteur (bar / mbar)',
        TileSlotType.lph => 'Débit carburant (L/h)',
        TileSlotType.avgSpeed => 'Vitesse moyenne trajet',
        TileSlotType.oilTemp => 'Temp. huile (°C)',
      };

  String get unitHint => switch (this) {
        TileSlotType.coolant => '°C',
        TileSlotType.intakeAir => '°C',
        TileSlotType.battery => 'V',
        TileSlotType.injection => 'ms / mg/c',
        TileSlotType.lambda => '%',
        TileSlotType.autoAir => 'auto',
        TileSlotType.rpm => 'tr/min',
        TileSlotType.speed => 'km/h',
        TileSlotType.maf => 'g/s',
        TileSlotType.throttle => '° / %',
        TileSlotType.load => '%',
        TileSlotType.boost => 'bar / mbar',
        TileSlotType.lph => 'L/h',
        TileSlotType.avgSpeed => 'km/h',
        TileSlotType.oilTemp => '°C',
      };
}

/// Préréglages complets de tableau de bord en 1 clic.
class DashboardPreset {
  const DashboardPreset({
    required this.name,
    required this.description,
    required this.heroes,
    required this.tiles,
  });

  final String name;
  final String description;
  final List<HeroSlotType> heroes;
  final List<TileSlotType> tiles;

  static const defaultHeroes = [HeroSlotType.conso, HeroSlotType.range];
  static const defaultTiles = [
    TileSlotType.coolant,
    TileSlotType.intakeAir,
    TileSlotType.battery,
    TileSlotType.injection,
    TileSlotType.lambda,
    TileSlotType.autoAir,
  ];

  static const all = <DashboardPreset>[
    DashboardPreset(
      name: 'OEM Conso & Santé (défaut)',
      description: 'Consommation + Autonomie • Températures, Batterie, Injection, Lambda, Air/Turbo',
      heroes: defaultHeroes,
      tiles: defaultTiles,
    ),
    DashboardPreset(
      name: 'Sport — Vitesse & RPM',
      description: 'Vitesse + Compte-tours RPM en grand • Eau, Charge, Batterie, Turbo/MAF, Papillon, Injection',
      heroes: [HeroSlotType.speed, HeroSlotType.rpm],
      tiles: [
        TileSlotType.coolant,
        TileSlotType.load,
        TileSlotType.battery,
        TileSlotType.autoAir,
        TileSlotType.throttle,
        TileSlotType.injection,
      ],
    ),
    DashboardPreset(
      name: 'Conduite mixte (Conso + RPM)',
      description: 'Consommation + Autonomie • Vitesse, RPM, Eau, Batterie, Lambda, Papillon',
      heroes: [HeroSlotType.conso, HeroSlotType.range],
      tiles: [
        TileSlotType.speed,
        TileSlotType.rpm,
        TileSlotType.coolant,
        TileSlotType.battery,
        TileSlotType.lambda,
        TileSlotType.throttle,
      ],
    ),
  ];
}

HeroSlotType heroSlotFromName(String name, HeroSlotType fallback) {
  for (final v in HeroSlotType.values) {
    if (v.name == name) return v;
  }
  return fallback;
}

TileSlotType tileSlotFromName(String name, TileSlotType fallback) {
  for (final v in TileSlotType.values) {
    if (v.name == name) return v;
  }
  return fallback;
}
