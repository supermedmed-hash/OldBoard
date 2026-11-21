/// Donnees moteur identifiees par "role" (independamment du groupe VAG d'origine).
enum EngineRole {
  rpm,
  speed,
  coolant,
  oilTemp,
  intakeAir,
  battery,
  injection,
  map,
  maf,
  throttle,
  load,
  lambda,
  cutoff,
  fuelMg,
  fuelLph,
}

extension EngineRoleInfo on EngineRole {
  String get label => switch (this) {
        EngineRole.rpm => 'Régime moteur',
        EngineRole.speed => 'Vitesse',
        EngineRole.coolant => 'Temp. moteur (culasse G62)',
        EngineRole.oilTemp => 'Temp. huile',
        EngineRole.intakeAir => 'Temp. air admission (G42)',
        EngineRole.battery => 'Tension batterie',
        EngineRole.injection => "Temps d'injection",
        EngineRole.map => 'Pression collecteur',
        EngineRole.maf => "Débit d'air (MAF G70)",
        EngineRole.throttle => 'Angle papillon',
        EngineRole.load => 'Charge moteur',
        EngineRole.lambda => 'Régulation lambda',
        EngineRole.cutoff => 'Coupure frein moteur',
        EngineRole.fuelMg => 'Quantité injectée (TDI mg/c)',
        EngineRole.fuelLph => 'Débit carburant (L/h)',
      };
}

class TimedValue {
  final double value;
  final DateTime at;
  TimedValue(this.value, this.at);
}

class EngineData {
  final Map<EngineRole, TimedValue> _values = {};

  void set(EngineRole r, double v) => _values[r] = TimedValue(v, DateTime.now());

  double? get(EngineRole r, {Duration maxAge = const Duration(seconds: 4)}) {
    final t = _values[r];
    if (t == null) return null;
    if (DateTime.now().difference(t.at) > maxAge) return null;
    return t.value;
  }

  void clear() => _values.clear();
}
