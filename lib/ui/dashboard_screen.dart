import 'package:flutter/material.dart';

import '../models/engine_data.dart';
import '../services/dashboard_controller.dart';
import 'diag_screen.dart';
import 'profile_picker_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.c});
  final DashboardController c;

  String _f(double? v, int d, [String dash = '—']) => v == null ? dash : v.toStringAsFixed(d);

  RangeStatus _check(double? v, double min, double max) {
    if (v == null) return RangeStatus.unknown;
    if (v < min) return RangeStatus.low;
    if (v > max) return RangeStatus.high;
    return RangeStatus.normal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Retro.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, box) {
                final isLandscape = box.maxWidth > box.maxHeight;
                return Column(
                  children: [
                    _topHeader(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        child: isLandscape ? _landscapeBody(context) : _portraitBody(context),
                      ),
                    ),
                    _bottomBar(context),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ EN-TÊTE + LÉGENDE COULEURS
  Widget _topHeader() {
    final now = DateTime.now();
    final clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final dotColor = switch (c.connState) {
      'connected' => Retro.green,
      'sim' => Retro.blue,
      'error' => Retro.red,
      'idle' || 'disconnected' => Retro.muted,
      _ => Retro.amber,
    };

    final prof = c.s.profile;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Retro.bg,
        border: Border(bottom: BorderSide(color: Retro.borderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          BrandEmblem(brand: prof.brand, accent: prof.accent, size: 26),
          const SizedBox(width: 8),
          Container(width: 2, height: 15, color: prof.accent),
          const SizedBox(width: 8),
          Text(
            prof.headerShort,
            style: const TextStyle(
              color: Retro.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const Spacer(),
          // Légende claire Bleu = Bas / Rouge = Haut
          _legendChip(Retro.blue, 'BAS'),
          const SizedBox(width: 6),
          _legendChip(Retro.green, 'OK'),
          const SizedBox(width: 6),
          _legendChip(Retro.red, 'HAUT'),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Retro.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Retro.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
                const SizedBox(width: 6),
                Text(
                  c.status.toUpperCase(),
                  style: const TextStyle(
                    color: Retro.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            clock,
            style: Retro.num(13, w: FontWeight.w700, c: Retro.white, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _legendChip(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ DISPOSITION PORTRAIT
  Widget _portraitBody(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 34,
          child: Row(
            children: [
              Expanded(child: _consoHeroCard()),
              const SizedBox(width: 8),
              Expanded(child: _rangeHeroCard()),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 23,
          child: _tempsAndElecRow(),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 23,
          child: _engineTelemetryRow(),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 20,
          child: _tripRow(),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ DISPOSITION PAYSAGE
  Widget _landscapeBody(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 52,
          child: Column(
            children: [
              Expanded(
                flex: 60,
                child: Row(
                  children: [
                    Expanded(child: _consoHeroCard()),
                    const SizedBox(width: 8),
                    Expanded(child: _rangeHeroCard()),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(flex: 40, child: _tripRow()),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 48,
          child: Column(
            children: [
              Expanded(child: _tempsAndElecRow()),
              const SizedBox(height: 8),
              Expanded(child: _engineTelemetryRow()),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ CARTES PRINCIPALES (CONSO & AUTONOMIE)
  Widget _consoHeroCard() {
    final inst = c.l100Inst;
    final running = (c.rpm ?? 0) > 300;
    final isCutoff = c.isCutoff;
    final mainVal = isCutoff
        ? '0.0'
        : (inst != null ? inst.clamp(0.0, 99.9).toStringAsFixed(1) : c.lph.toStringAsFixed(1));
    final mainUnit = isCutoff ? 'L/100' : (inst != null ? 'L/100' : 'L/h');

    final prof = c.s.profile;
    // Cotes conso adaptees au profil (Essence vs Diesel TDI)
    final RangeStatus status;
    if (!running) {
      status = RangeStatus.unknown;
    } else if (isCutoff) {
      status = RangeStatus.low; // Coupure injection -> Bleu
    } else if (inst != null) {
      status = _check(inst, prof.consoMin, prof.consoMax);
    } else {
      status = _check(c.lph, prof.idleLphMin, prof.idleLphMax);
    }

    final barFrac = isCutoff
        ? 0.0
        : (inst != null ? (inst / (prof.consoMax + 4.5)).clamp(0.0, 1.0) : (c.lph / 4.0).clamp(0.0, 1.0));

    return _heroCard(
      title: 'CONSOMMATION',
      spec: isCutoff
          ? 'COUPURE INJ.'
          : (inst != null
              ? 'COTE ${prof.consoMin.toStringAsFixed(1)}–${prof.consoMax.toStringAsFixed(1)}'
              : 'RALENTI ${prof.idleLphMin.toStringAsFixed(1)}–${prof.idleLphMax.toStringAsFixed(1)}'),
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(mainVal, style: Retro.num(50, w: FontWeight.w800, c: Retro.valueColor(status))),
                  const SizedBox(width: 8),
                  Text(mainUnit, style: Retro.title(14, c: Retro.silver)),
                ],
              ),
            ),
          ),
          _segmentedBar(
            fraction: barFrac,
            segments: 20,
            activeColor: status == RangeStatus.normal ? Retro.white : Retro.valueColor(status),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _subMetric(
                  'MOY. TRAJET',
                  c.tripAvgL100 > 0 ? '${c.tripAvgL100.toStringAsFixed(1)} L/100' : '—',
                  _check(c.tripAvgL100 > 0 ? c.tripAvgL100 : null, 4.5, 10.5),
                ),
              ),
              Container(width: 1, height: 24, color: Retro.border),
              const SizedBox(width: 8),
              Expanded(
                child: _subMetric(
                  'DÉBIT DIRECT',
                  '${c.lph.toStringAsFixed(1)} L/h',
                  RangeStatus.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rangeHeroCard() {
    final frac = (c.s.fuelRemaining / c.s.tankCapacity).clamp(0.0, 1.0);
    // Cote réservoir : < 8 L (réserve) = Trop bas (Bleu) ; > 55 L = Trop haut (Rouge)
    final status = _check(c.s.fuelRemaining, 8.0, c.s.tankCapacity);

    return _heroCard(
      title: 'AUTONOMIE',
      spec: '${(frac * 100).toStringAsFixed(0)}% RÉSERVOIR',
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(c.rangeKm.toStringAsFixed(0), style: Retro.num(50, w: FontWeight.w800, c: Retro.valueColor(status))),
                  const SizedBox(width: 8),
                  Text('KM', style: Retro.title(14, c: Retro.silver)),
                ],
              ),
            ),
          ),
          _segmentedBar(
            fraction: frac,
            segments: 20,
            activeColor: status == RangeStatus.low ? Retro.blue : c.s.profile.accent,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _subMetric(
                  'RESTE RÉSERVOIR',
                  '${c.s.fuelRemaining.toStringAsFixed(1)} / ${c.s.tankCapacity.toStringAsFixed(0)} L',
                  status,
                ),
              ),
              Container(width: 1, height: 24, color: Retro.border),
              const SizedBox(width: 8),
              Expanded(
                child: _subMetric(
                  'CONSO TRAJET',
                  '${c.s.tripFuel.toStringAsFixed(2)} L',
                  RangeStatus.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subMetric(String label, String value, RangeStatus status) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Retro.title(10, c: Retro.silver, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: Retro.num(13.5, w: FontWeight.w700, c: Retro.valueColor(status), letterSpacing: -0.2)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ TEMPÉRATURES MOTEUR & ÉLECTRICITÉ
  Widget _tempsAndElecRow() {
    final coolant = c.data.get(EngineRole.coolant);
    final oil = c.data.get(EngineRole.oilTemp);
    final iat = c.data.get(EngineRole.intakeAir);
    final batt = c.data.get(EngineRole.battery);
    final running = (c.rpm ?? 0) > 400;

    // 1. Cote Temp. Moteur (Sonde culasse G62) : 80 °C .. 105 °C
    final coolantStatus = _check(coolant, 80, 105);
    final coolantSub = switch (coolantStatus) {
      RangeStatus.low => 'FROID (< 80°C)',
      RangeStatus.normal => 'OPTIMAL (80–105°C)',
      RangeStatus.high => 'SURCHAUFFE (> 105°C)',
      RangeStatus.unknown => 'COTE 80–105°C',
    };

    // 2. Cote Air Admission (G42) : 5 °C .. 60 °C (ou Huile : 80 °C .. 120 °C)
    final hasOil = oil != null;
    final secondStatus = hasOil ? _check(oil, 80, 120) : _check(iat, 5, 60);
    final secondSub = hasOil
        ? switch (secondStatus) {
            RangeStatus.low => 'HUILE FROIDE (< 80°C)',
            RangeStatus.normal => 'OPTIMAL (80–120°C)',
            RangeStatus.high => 'TROP CHAUDE (> 120°C)',
            RangeStatus.unknown => 'COTE 80–120°C',
          }
        : switch (secondStatus) {
            RangeStatus.low => 'AIR FROID (< 5°C)',
            RangeStatus.normal => 'NORMAL (5–60°C)',
            RangeStatus.high => 'AIR CHAUD (> 60°C)',
            RangeStatus.unknown => 'COTE 5–60°C',
          };

    // 3. Cote Tension Batterie : 13.2 V .. 14.6 V moteur tournant (12.0 .. 14.6 V moteur arrêté)
    final minVolt = running ? 13.2 : 12.0;
    final battStatus = _check(batt, minVolt, 14.6);
    final battSub = switch (battStatus) {
      RangeStatus.low => 'TROP BAS (< ${minVolt.toStringAsFixed(1)}V)',
      RangeStatus.normal => 'NORMAL (${minVolt.toStringAsFixed(1)}–14.6V)',
      RangeStatus.high => 'SURTENSION (> 14.6V)',
      RangeStatus.unknown => 'COTE 13.2–14.6V',
    };

    return Row(
      children: [
        Expanded(
          child: _metricTile(
            label: 'TEMP. MOTEUR',
            value: _f(coolant, 0),
            unit: '°C',
            sub: coolantSub,
            status: coolantStatus,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            label: hasOil ? 'TEMP. HUILE' : 'AIR ADMISSION',
            value: hasOil ? _f(oil, 0) : _f(iat, 0),
            unit: '°C',
            sub: secondSub,
            status: secondStatus,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            label: 'BATTERIE',
            value: _f(batt, 2),
            unit: 'V',
            sub: battSub,
            status: battStatus,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ TÉLÉMÉTRIE MOTEUR (ESSENCE / TURBO / DIESEL TDI)
  Widget _engineTelemetryRow() {
    final prof = c.s.profile;
    final inj = c.data.get(EngineRole.injection);
    final map = c.data.get(EngineRole.map);
    final maf = c.data.get(EngineRole.maf);
    final thr = c.data.get(EngineRole.throttle);
    final lam = c.data.get(EngineRole.lambda);
    final mg = c.data.get(EngineRole.fuelMg);

    // Mode Diesel 1.9 TDI (EDC15) : Injection mg/coup + Pression Turbo bar + MAF / Pédale %
    if (prof.isDiesel) {
      final mgStatus = c.isCutoff ? RangeStatus.low : _check(mg, 1.5, 55.0);
      final boostBar = map != null ? (map - 1013.0) / 1000.0 : null;
      final boostStatus = _check(boostBar, -0.1, 1.55);
      final mafStatus = _check(maf, 180, 1150);
      return Row(
        children: [
          Expanded(
            child: _metricTile(
              label: 'INJECTION TDI',
              value: c.isCutoff ? '0.0' : _f(mg, 1),
              unit: 'mg/c',
              sub: c.isCutoff ? 'COUPURE FREIN MOTEUR' : 'RALENTI 2.5–9 mg/c',
              status: mgStatus,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricTile(
              label: 'TURBO (GRP 11)',
              value: boostBar == null ? '—' : '${boostBar >= 0 ? '+' : ''}${boostBar.toStringAsFixed(2)}',
              unit: 'bar',
              sub: map != null ? '${map.toStringAsFixed(0)} mbar abs.' : 'COTE 0.0–1.55 bar',
              status: boostStatus,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricTile(
              label: maf != null ? 'DÉBIT AIR (MAF)' : 'PÉDALE',
              value: maf != null ? _f(maf, 0) : _f(thr, 0),
              unit: maf != null ? 'mg/h' : '%',
              sub: thr != null ? 'PÉDALE ${thr.toStringAsFixed(0)} %' : 'SONDE G70',
              status: maf != null ? mafStatus : _check(thr, 0, 100),
            ),
          ),
        ],
      );
    }

    // 1. Cote Temps d'injection Essence : 1.8 ms .. 15.0 ms (< 1.8 ms ou isCutoff = coupure -> Bleu, > 15 ms -> Rouge)
    final effectiveInj = c.isCutoff ? 0.0 : inj;
    final injStatus = c.isCutoff ? RangeStatus.low : _check(inj, 1.8, 15.0);
    final injSub = switch (injStatus) {
      RangeStatus.low => c.isCutoff ? 'COUPURE FREIN MOTEUR' : 'COUPURE (< 1.8 ms)',
      RangeStatus.normal => 'NORMAL (1.8–15 ms)',
      RangeStatus.high => 'MAX (> 15.0 ms)',
      RangeStatus.unknown => 'COTE 1.8–15 ms',
    };

    // 2. Cote Lambda G39 : -10 % .. +10 % (< -10 % = Trop riche -> Bleu ; > +10 % = Prise d'air / Pauvre -> Rouge)
    final lamStatus = _check(lam, -10.0, 10.0);
    final lamVal = lam == null ? '—' : '${lam >= 0 ? '+' : ''}${lam.toStringAsFixed(1)}';
    final lamSub = switch (lamStatus) {
      RangeStatus.low => 'TROP RICHE (< -10%)',
      RangeStatus.normal => 'MÉLANGE OK (-10..+10%)',
      RangeStatus.high => 'PRISE D\'AIR (> +10%)',
      RangeStatus.unknown => 'COTE -10..+10%',
    };

    // 3. Cote Turbo (1.8T ME7.5 Grp 115) ou Collecteur MAP (mbar) ou Débit air MAF (g/s) ou Papillon (°)
    final RangeStatus thirdStatus;
    final String thirdLabel;
    final String thirdVal;
    final String thirdUnit;
    final String thirdSub;

    if (prof.hasTurbo && map != null) {
      final boostBar = (map - 1013.0) / 1000.0;
      thirdLabel = 'TURBO (GRP 115)';
      thirdVal = '${boostBar >= 0 ? '+' : ''}${boostBar.toStringAsFixed(2)}';
      thirdUnit = 'bar';
      thirdStatus = _check(boostBar, -0.75, 1.35);
      thirdSub = '${map.toStringAsFixed(0)} mbar abs.';
    } else if (map != null) {
      thirdLabel = 'COLLECTEUR';
      thirdVal = _f(map, 0);
      thirdUnit = 'mbar';
      thirdStatus = _check(map, 250, 950);
      thirdSub = switch (thirdStatus) {
        RangeStatus.low => 'DÉPRESSION (< 250)',
        RangeStatus.normal => 'NORMAL (250–950)',
        RangeStatus.high => 'PLEINE CHARGE (> 950)',
        RangeStatus.unknown => 'COTE 250–950',
      };
    } else if (maf != null) {
      thirdLabel = 'DÉBIT AIR';
      thirdVal = _f(maf, 1);
      thirdUnit = 'g/s';
      thirdStatus = _check(maf, 2.0, prof.hasTurbo ? 160.0 : 85.0);
      thirdSub = thr != null ? 'PAP ${thr.toStringAsFixed(1)}° • G70' : 'COTE 2–85 g/s';
    } else {
      thirdLabel = 'PAPILLON';
      thirdVal = _f(thr, 1);
      thirdUnit = '°';
      thirdStatus = _check(thr, 2.0, 80.0);
      thirdSub = switch (thirdStatus) {
        RangeStatus.low => 'FERMÉ (< 2°)',
        RangeStatus.normal => 'NORMAL (2–80°)',
        RangeStatus.high => 'PLEIN GAZ (> 80°)',
        RangeStatus.unknown => 'COTE 2–80°',
      };
    }

    return Row(
      children: [
        Expanded(
          child: _metricTile(
            label: 'INJECTION',
            value: _f(effectiveInj, 2),
            unit: 'ms',
            sub: injSub,
            status: injStatus,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            label: 'LAMBDA (G39)',
            value: lamVal,
            unit: '%',
            sub: lamSub,
            status: lamStatus,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            label: thirdLabel,
            value: thirdVal,
            unit: thirdUnit,
            sub: thirdSub,
            status: thirdStatus,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ ORDINATEUR DE TRAJET
  Widget _tripRow() {
    final secs = c.s.tripSeconds.round();
    final dur = '${secs ~/ 3600}h${((secs % 3600) ~/ 60).toString().padLeft(2, '0')}';
    final avgStatus = _check(c.tripAvgL100 > 0 ? c.tripAvgL100 : null, 4.5, 10.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Retro.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Retro.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: c.s.profile.accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('ORDINATEUR DE TRAJET', style: Retro.title(12, c: Retro.titleWhite)),
              const Spacer(),
              InkWell(
                onTap: c.resetTrip,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Retro.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Retro.border, width: 1),
                  ),
                  child: Text('REMISE À ZÉRO', style: Retro.title(10, c: Retro.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                _tripStat('DISTANCE', _f(c.s.tripKm, 1), 'km', RangeStatus.normal),
                _verticalDivider(),
                _tripStat('DURÉE', dur, '', RangeStatus.normal),
                _verticalDivider(),
                _tripStat(
                  'MOYENNE',
                  c.tripAvgL100 > 0 ? c.tripAvgL100.toStringAsFixed(1) : '—',
                  'L/100',
                  avgStatus,
                ),
                _verticalDivider(),
                _tripStat('CARBURANT', c.s.tripFuel.toStringAsFixed(2), 'L', RangeStatus.normal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        color: Retro.border,
      );

  Widget _tripStat(String label, String val, String unit, RangeStatus status) {
    final col = Retro.valueColor(status);
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Retro.title(10.5, c: Retro.silver, w: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(val, style: Retro.num(21, w: FontWeight.w800, c: col, letterSpacing: -0.4)),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unit, style: Retro.title(11, c: Retro.silver)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ COMPOSANTS VISUELS HAUTE PRÉCISION
  Widget _heroCard({
    required String title,
    required String spec,
    required RangeStatus status,
    required Widget child,
  }) {
    final borderCol = Retro.borderColor(status);
    final topBarCol = switch (status) {
      RangeStatus.low => Retro.blue,
      RangeStatus.high => Retro.red,
      RangeStatus.normal => c.s.profile.accent,
      RangeStatus.unknown => c.s.profile.accent,
    };

    return Container(
      decoration: BoxDecoration(
        color: Retro.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderCol,
          width: status == RangeStatus.low || status == RangeStatus.high ? 1.8 : 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3, color: topBarCol),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Retro.title(13, c: Retro.titleWhite),
                        ),
                      ),
                      _statusBadge(spec, status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, RangeStatus status) {
    final col = switch (status) {
      RangeStatus.low => Retro.blue,
      RangeStatus.high => Retro.red,
      RangeStatus.normal => Retro.silver,
      RangeStatus.unknown => Retro.grey,
    };
    final bg = switch (status) {
      RangeStatus.low => Retro.blue.withValues(alpha: 0.16),
      RangeStatus.high => Retro.red.withValues(alpha: 0.16),
      _ => Retro.surfaceElevated,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: status == RangeStatus.normal || status == RangeStatus.unknown ? Retro.border : col),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.3),
      ),
    );
  }

  Widget _segmentedBar({
    required double fraction,
    required int segments,
    required Color activeColor,
  }) {
    final activeCount = (fraction.clamp(0.0, 1.0) * segments).round();
    return SizedBox(
      height: 6,
      child: Row(
        children: [
          for (var i = 0; i < segments; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: i < activeCount ? activeColor : const Color(0xFF1F212A),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required String unit,
    required String sub,
    required RangeStatus status,
  }) {
    final valCol = Retro.valueColor(status);
    final borderCol = Retro.borderColor(status);
    final dotCol = Retro.indicatorColor(status);
    final isOut = status == RangeStatus.low || status == RangeStatus.high;

    return Container(
      decoration: BoxDecoration(
        color: Retro.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: isOut ? 1.8 : 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bandeau de titre très lisible à contraste élevé
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isOut ? valCol.withValues(alpha: 0.14) : Retro.surfaceHeader,
              border: const Border(bottom: BorderSide(color: Retro.borderSubtle, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: Retro.title(12.5, c: Retro.titleWhite),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotCol, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          // Valeur + Sous-texte de cote
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(value, style: Retro.num(34, w: FontWeight.w800, c: valCol)),
                          if (unit.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(unit, style: Retro.title(13, c: isOut ? valCol : Retro.silver)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      sub,
                      maxLines: 1,
                      style: TextStyle(
                        color: isOut ? valCol : Retro.silver,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ BARRE D'ACTIONS BAS
  Widget _bottomBar(BuildContext context) {
    final carOn = c.mode == SourceMode.car;
    final simOn = c.mode == SourceMode.sim;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: Retro.bg,
        border: Border(top: BorderSide(color: Retro.borderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _actionBtn(
              carOn ? 'STOP USB' : 'CÂBLE USB',
              carOn ? c.disconnectCar : c.connectCar,
              active: carOn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionBtn(
              simOn ? 'STOP SIMU' : 'SIMULATION',
              simOn ? c.stopSim : c.startSim,
              active: simOn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionBtn('PLEIN', () => showRefuelDialog(context, c)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionBtn(
              'DIAGNOSTIC',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiagScreen(c: c))),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 36,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(c: c))),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Retro.surface,
                side: const BorderSide(color: Retro.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Icon(Icons.tune_rounded, size: 18, color: Retro.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap, {bool active = false}) {
    final accent = c.s.profile.accent;
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Retro.white,
          backgroundColor: active ? accent : Retro.surface,
          side: BorderSide(color: active ? accent : Retro.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ),
      ),
    );
  }
}

Future<void> showRefuelDialog(BuildContext context, DashboardController c) async {
  final ctrl = TextEditingController();
  var full = true;
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: Retro.surface,
        title: const Text('Passage à la pompe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Litres mis (indiqués par la pompe)'),
              ),
              CheckboxListTile(
                value: full,
                onChanged: (v) => setS(() => full = v ?? true),
                title: const Text('Plein complet'),
                subtitle: const Text('Recale la jauge et calibre la conso automatiquement'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final l = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
              Navigator.pop(ctx, c.refuel(liters: l, full: full));
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    ),
  );
  if (res != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
  }
}
