import 'package:flutter/material.dart';

import '../models/dashboard_layout.dart';
import '../models/engine_data.dart';
import '../services/dashboard_controller.dart';
import '../services/update_service.dart';
import 'dashboard_editor_screen.dart';
import 'diag_screen.dart';
import 'profile_picker_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'update_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.c, this.updater});
  final DashboardController c;
  final UpdateService? updater;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Set<String> _promptedTags = {};

  DashboardController get c => widget.c;
  UpdateService? get updater => widget.updater;

  @override
  void initState() {
    super.initState();
    updater?.addListener(_onUpdateEvent);
    _onUpdateEvent();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updater != widget.updater) {
      oldWidget.updater?.removeListener(_onUpdateEvent);
      widget.updater?.addListener(_onUpdateEvent);
    }
  }

  @override
  void dispose() {
    updater?.removeListener(_onUpdateEvent);
    super.dispose();
  }

  void _onUpdateEvent() {
    final u = updater;
    final rel = u?.availableUpdate;
    if (u == null || rel == null) return;
    if (rel.tag == c.s.ignoredUpdateTag || _promptedTags.contains(rel.tag)) return;
    _promptedTags.add(rel.tag);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showUpdateDialog(context, updater: u, settings: c.s, release: rel);
    });
  }

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
          listenable: Listenable.merge([c, c.s]),
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, box) {
                final isLandscape = box.maxWidth > box.maxHeight;
                final compactW = box.maxWidth < 360;
                final compactH = box.maxHeight < 430;
                final gap = compactW || compactH ? 6.0 : 8.0;
                final padH = compactW ? 6.0 : 10.0;
                final padV = compactH ? 4.0 : 6.0;
                return Column(
                  children: [
                    _topHeader(box.maxWidth, compactH),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
                        child: isLandscape
                            ? _landscapeBody(context, gap)
                            : _portraitBody(context, gap),
                      ),
                    ),
                    _bottomBar(context, box.maxWidth, compactH),
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
  Widget _topHeader(double maxWidth, bool compactH) {
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
    final compactW = maxWidth < 360;
    final showInlineLegend = maxWidth >= 520;
    final showSubLegend = !showInlineLegend && !compactH;

    return Container(
      decoration: const BoxDecoration(
        color: Retro.bg,
        border: Border(bottom: BorderSide(color: Retro.borderSubtle, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: compactH ? 36 : 42),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compactW ? 8 : 12, vertical: compactH ? 4 : 6),
              child: Row(
                children: [
                  BrandEmblem(brand: prof.brand, accent: prof.accent, size: compactW ? 22 : 25),
                  SizedBox(width: compactW ? 6 : 8),
                  Container(width: 2, height: 14, color: prof.accent),
                  SizedBox(width: compactW ? 6 : 8),
                  Expanded(
                    flex: 4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        prof.headerShort,
                        maxLines: 1,
                        style: TextStyle(
                          color: Retro.white,
                          fontSize: compactW ? 12 : 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ),
                  if (showInlineLegend) ...[
                    const SizedBox(width: 8),
                    _legendChip(Retro.blue, 'BAS'),
                    const SizedBox(width: 6),
                    _legendChip(Retro.green, 'OK'),
                    const SizedBox(width: 6),
                    _legendChip(Retro.red, 'HAUT'),
                  ],
                  SizedBox(width: compactW ? 6 : 8),
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: compactW ? 7 : 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Retro.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Retro.border, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                c.status.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Retro.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: compactW ? 6 : 10),
                  Text(
                    clock,
                    style: Retro.num(compactW ? 12 : 13, w: FontWeight.w700, c: Retro.white, letterSpacing: 0.4),
                  ),
                ],
              ),
            ),
          ),
          if (showSubLegend)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: const BoxDecoration(
                color: Retro.surface,
                border: Border(top: BorderSide(color: Retro.borderSubtle, width: 1)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendChip(Retro.blue, 'TROP BAS'),
                    const SizedBox(width: 14),
                    _legendChip(Retro.green, 'DANS LES COTES'),
                    const SizedBox(width: 14),
                    _legendChip(Retro.red, 'TROP HAUT'),
                  ],
                ),
              ),
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
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ DISPOSITION PORTRAIT
  Widget _portraitBody(BuildContext context, double gap) {
    return Column(
      children: [
        Expanded(
          flex: 35,
          child: Row(
            children: [
              Expanded(child: _buildHeroSlot(context, 0)),
              SizedBox(width: gap),
              Expanded(child: _buildHeroSlot(context, 1)),
            ],
          ),
        ),
        SizedBox(height: gap),
        Expanded(
          flex: 22,
          child: _tileRow(context, 0, gap),
        ),
        SizedBox(height: gap),
        Expanded(
          flex: 22,
          child: _tileRow(context, 3, gap),
        ),
        SizedBox(height: gap),
        Expanded(
          flex: 21,
          child: _tripRow(),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ DISPOSITION PAYSAGE
  Widget _landscapeBody(BuildContext context, double gap) {
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
                    Expanded(child: _buildHeroSlot(context, 0)),
                    SizedBox(width: gap),
                    Expanded(child: _buildHeroSlot(context, 1)),
                  ],
                ),
              ),
              SizedBox(height: gap),
              Expanded(flex: 40, child: _tripRow()),
            ],
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: 48,
          child: Column(
            children: [
              Expanded(child: _tileRow(context, 0, gap)),
              SizedBox(height: gap),
              Expanded(child: _tileRow(context, 3, gap)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSlot(BuildContext context, int index) {
    final slot = c.s.heroSlots[index];
    final card = switch (slot) {
      HeroSlotType.conso => _consoHeroCard(),
      HeroSlotType.range => _rangeHeroCard(),
      HeroSlotType.speed => _speedHeroCard(),
      HeroSlotType.rpm => _rpmHeroCard(),
    };
    return GestureDetector(
      onLongPress: () => showHeroSlotPicker(context, settings: c.s, slotIndex: index),
      child: card,
    );
  }

  Widget _tileRow(BuildContext context, int startIndex, double gap) {
    return Row(
      children: [
        Expanded(child: _buildTileSlot(context, startIndex)),
        SizedBox(width: gap),
        Expanded(child: _buildTileSlot(context, startIndex + 1)),
        SizedBox(width: gap),
        Expanded(child: _buildTileSlot(context, startIndex + 2)),
      ],
    );
  }

  Widget _buildTileSlot(BuildContext context, int index) {
    final slot = c.s.tileSlots[index];
    return GestureDetector(
      onLongPress: () => showTileSlotPicker(context, settings: c.s, slotIndex: index),
      child: _tileForType(slot),
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
      builder: (compactH) => Column(
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
            height: compactH ? 4.5 : 6,
            activeColor: status == RangeStatus.normal ? Retro.white : Retro.valueColor(status),
          ),
          SizedBox(height: compactH ? 4 : 8),
          Row(
            children: [
              Expanded(
                child: _subMetric(
                  'MOY. TRAJET',
                  c.tripAvgL100 > 0 ? '${c.tripAvgL100.toStringAsFixed(1)} L/100' : '—',
                  _check(c.tripAvgL100 > 0 ? c.tripAvgL100 : null, 4.5, 10.5),
                ),
              ),
              const SizedBox(width: 6),
              Container(width: 1, height: compactH ? 20 : 24, color: Retro.border),
              const SizedBox(width: 6),
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
      builder: (compactH) => Column(
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
            height: compactH ? 4.5 : 6,
            activeColor: status == RangeStatus.low ? Retro.blue : c.s.profile.accent,
          ),
          SizedBox(height: compactH ? 4 : 8),
          Row(
            children: [
              Expanded(
                child: _subMetric(
                  'RESTE RÉSERVOIR',
                  '${c.s.fuelRemaining.toStringAsFixed(1)} / ${c.s.tankCapacity.toStringAsFixed(0)} L',
                  status,
                ),
              ),
              const SizedBox(width: 6),
              Container(width: 1, height: compactH ? 20 : 24, color: Retro.border),
              const SizedBox(width: 6),
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

  Widget _speedHeroCard() {
    final spd = c.data.get(EngineRole.speed);
    final val = spd == null ? '—' : spd.toStringAsFixed(0);
    final status = spd == null ? RangeStatus.unknown : _check(spd, 0, 135);
    final barFrac = spd == null ? 0.0 : (spd / 200.0).clamp(0.0, 1.0);

    return _heroCard(
      title: 'VITESSE',
      spec: spd == null ? 'CAPTEUR OBD' : (spd > 130 ? 'AUTOROUTE' : 'RÉELLE ECU'),
      status: status,
      builder: (compactH) => Column(
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
                  Text(val, style: Retro.num(50, w: FontWeight.w800, c: Retro.valueColor(status))),
                  const SizedBox(width: 8),
                  Text('KM/H', style: Retro.title(14, c: Retro.silver)),
                ],
              ),
            ),
          ),
          _segmentedBar(
            fraction: barFrac,
            segments: 20,
            height: compactH ? 4.5 : 6,
            activeColor: status == RangeStatus.high ? Retro.red : c.s.profile.accent,
          ),
          SizedBox(height: compactH ? 4 : 8),
          Row(
            children: [
              Expanded(
                child: _subMetric(
                  'MOY. TRAJET',
                  c.tripAvgSpeed > 0 ? '${c.tripAvgSpeed.toStringAsFixed(0)} km/h' : '—',
                  RangeStatus.normal,
                ),
              ),
              const SizedBox(width: 6),
              Container(width: 1, height: compactH ? 20 : 24, color: Retro.border),
              const SizedBox(width: 6),
              Expanded(
                child: _subMetric(
                  'DISTANCE',
                  '${c.s.tripKm.toStringAsFixed(1)} km',
                  RangeStatus.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rpmHeroCard() {
    final rpm = c.rpm;
    final shift = c.s.shiftRpm.toDouble();
    final maxScale = c.s.profile.isDiesel ? 5000.0 : 7000.0;
    final status = rpm == null
        ? RangeStatus.unknown
        : (rpm < 550 ? RangeStatus.low : (rpm >= shift ? RangeStatus.high : RangeStatus.normal));
    final barFrac = rpm == null ? 0.0 : (rpm / maxScale).clamp(0.0, 1.0);
    final thr = c.data.get(EngineRole.throttle);
    final load = c.data.get(EngineRole.load);

    return _heroCard(
      title: 'RÉGIME MOTEUR',
      spec: rpm == null
          ? 'ZONE ${shift.toStringAsFixed(0)} TR'
          : (rpm >= shift ? 'ZONE ROUGE !' : 'MAX ${c.s.maxRpm > 0 ? c.s.maxRpm.toStringAsFixed(0) : shift.toStringAsFixed(0)}'),
      status: status,
      builder: (compactH) => Column(
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
                  Text(
                    rpm == null ? '—' : rpm.toStringAsFixed(0),
                    style: Retro.num(50, w: FontWeight.w800, c: Retro.valueColor(status)),
                  ),
                  const SizedBox(width: 8),
                  Text('TR/MIN', style: Retro.title(13, c: Retro.silver)),
                ],
              ),
            ),
          ),
          _segmentedBar(
            fraction: barFrac,
            segments: 20,
            height: compactH ? 4.5 : 6,
            activeColor: status == RangeStatus.high ? Retro.red : (status == RangeStatus.low ? Retro.blue : c.s.profile.accent),
          ),
          SizedBox(height: compactH ? 4 : 8),
          Row(
            children: [
              Expanded(
                child: _subMetric(
                  'PAPILLON',
                  thr != null ? '${thr.toStringAsFixed(1)}°' : '—',
                  RangeStatus.normal,
                ),
              ),
              const SizedBox(width: 6),
              Container(width: 1, height: compactH ? 20 : 24, color: Retro.border),
              const SizedBox(width: 6),
              Expanded(
                child: _subMetric(
                  'CHARGE',
                  load != null ? '${load.toStringAsFixed(0)} %' : '—',
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Retro.title(9.5, c: Retro.silver, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: Retro.num(13.5, w: FontWeight.w700, c: Retro.valueColor(status), letterSpacing: -0.2)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ TUILES CAPTEURS PERSONNALISABLES
  Widget _tileForType(TileSlotType type) {
    final prof = c.s.profile;
    final running = (c.rpm ?? 0) > 400;

    switch (type) {
      case TileSlotType.coolant:
        final coolant = c.data.get(EngineRole.coolant);
        final st = _check(coolant, 80, 105);
        return _metricTile(
          label: 'TEMP. MOTEUR',
          value: _f(coolant, 0),
          unit: '°C',
          sub: switch (st) {
            RangeStatus.low => 'FROID (< 80°C)',
            RangeStatus.normal => 'OPTIMAL (80–105°C)',
            RangeStatus.high => 'SURCHAUFFE (> 105°C)',
            RangeStatus.unknown => 'COTE 80–105°C',
          },
          status: st,
        );

      case TileSlotType.intakeAir:
        final oil = c.data.get(EngineRole.oilTemp);
        final iat = c.data.get(EngineRole.intakeAir);
        final hasOil = oil != null;
        final st = hasOil ? _check(oil, 80, 120) : _check(iat, 5, 60);
        return _metricTile(
          label: hasOil ? 'TEMP. HUILE' : 'AIR ADMISSION',
          value: hasOil ? _f(oil, 0) : _f(iat, 0),
          unit: '°C',
          sub: hasOil
              ? switch (st) {
                  RangeStatus.low => 'HUILE FROIDE (< 80°C)',
                  RangeStatus.normal => 'OPTIMAL (80–120°C)',
                  RangeStatus.high => 'TROP CHAUDE (> 120°C)',
                  RangeStatus.unknown => 'COTE 80–120°C',
                }
              : switch (st) {
                  RangeStatus.low => 'AIR FROID (< 5°C)',
                  RangeStatus.normal => 'NORMAL (5–60°C)',
                  RangeStatus.high => 'AIR CHAUD (> 60°C)',
                  RangeStatus.unknown => 'COTE 5–60°C',
                },
          status: st,
        );

      case TileSlotType.oilTemp:
        final oil = c.data.get(EngineRole.oilTemp);
        final st = _check(oil, 80, 120);
        return _metricTile(
          label: 'TEMP. HUILE',
          value: _f(oil, 0),
          unit: '°C',
          sub: switch (st) {
            RangeStatus.low => 'HUILE FROIDE (< 80°C)',
            RangeStatus.normal => 'OPTIMAL (80–120°C)',
            RangeStatus.high => 'TROP CHAUDE (> 120°C)',
            RangeStatus.unknown => 'COTE 80–120°C',
          },
          status: st,
        );

      case TileSlotType.battery:
        final batt = c.data.get(EngineRole.battery);
        final minVolt = running ? 13.2 : 12.0;
        final st = _check(batt, minVolt, 14.6);
        return _metricTile(
          label: 'BATTERIE',
          value: _f(batt, 2),
          unit: 'V',
          sub: switch (st) {
            RangeStatus.low => 'TROP BAS (< ${minVolt.toStringAsFixed(1)}V)',
            RangeStatus.normal => 'NORMAL (${minVolt.toStringAsFixed(1)}–14.6V)',
            RangeStatus.high => 'SURTENSION (> 14.6V)',
            RangeStatus.unknown => 'COTE 13.2–14.6V',
          },
          status: st,
        );

      case TileSlotType.injection:
        if (prof.isDiesel) {
          final mg = c.data.get(EngineRole.fuelMg);
          final st = c.isCutoff ? RangeStatus.low : _check(mg, 1.5, 55.0);
          return _metricTile(
            label: 'INJECTION TDI',
            value: c.isCutoff ? '0.0' : _f(mg, 1),
            unit: 'mg/c',
            sub: c.isCutoff ? 'COUPURE FREIN MOTEUR' : 'RALENTI 2.5–9 mg/c',
            status: st,
          );
        }
        final inj = c.data.get(EngineRole.injection);
        final eff = c.isCutoff ? 0.0 : inj;
        final st = c.isCutoff ? RangeStatus.low : _check(inj, 1.8, 15.0);
        return _metricTile(
          label: 'INJECTION',
          value: _f(eff, 2),
          unit: 'ms',
          sub: switch (st) {
            RangeStatus.low => c.isCutoff ? 'COUPURE FREIN MOTEUR' : 'COUPURE (< 1.8 ms)',
            RangeStatus.normal => 'NORMAL (1.8–15 ms)',
            RangeStatus.high => 'MAX (> 15.0 ms)',
            RangeStatus.unknown => 'COTE 1.8–15 ms',
          },
          status: st,
        );

      case TileSlotType.lambda:
        final lam = c.data.get(EngineRole.lambda);
        if (prof.isDiesel && lam == null) {
          return _tileForType(TileSlotType.boost);
        }
        final st = _check(lam, -10.0, 10.0);
        return _metricTile(
          label: 'LAMBDA (G39)',
          value: lam == null ? '—' : '${lam >= 0 ? '+' : ''}${lam.toStringAsFixed(1)}',
          unit: '%',
          sub: switch (st) {
            RangeStatus.low => 'TROP RICHE (< -10%)',
            RangeStatus.normal => 'MÉLANGE OK (-10..+10%)',
            RangeStatus.high => 'PRISE D\'AIR (> +10%)',
            RangeStatus.unknown => 'COTE -10..+10%',
          },
          status: st,
        );

      case TileSlotType.autoAir:
        final map = c.data.get(EngineRole.map);
        final maf = c.data.get(EngineRole.maf);
        final thr = c.data.get(EngineRole.throttle);
        if (prof.isDiesel) {
          final mafSt = _check(maf, 180, 1150);
          return _metricTile(
            label: maf != null ? 'DÉBIT AIR (MAF)' : 'PÉDALE',
            value: maf != null ? _f(maf, 0) : _f(thr, 0),
            unit: maf != null ? 'mg/h' : '%',
            sub: thr != null ? 'PÉDALE ${thr.toStringAsFixed(0)} %' : 'SONDE G70',
            status: maf != null ? mafSt : _check(thr, 0, 100),
          );
        }
        if (prof.hasTurbo && map != null) return _tileForType(TileSlotType.boost);
        if (map != null) return _tileForType(TileSlotType.boost);
        if (maf != null) return _tileForType(TileSlotType.maf);
        return _tileForType(TileSlotType.throttle);

      case TileSlotType.rpm:
        final rpm = c.rpm;
        final shift = c.s.shiftRpm.toDouble();
        final st = rpm == null
            ? RangeStatus.unknown
            : (rpm < 550 ? RangeStatus.low : (rpm >= shift ? RangeStatus.high : RangeStatus.normal));
        return _metricTile(
          label: 'RÉGIME (RPM)',
          value: rpm == null ? '—' : rpm.toStringAsFixed(0),
          unit: 'tr/m',
          sub: switch (st) {
            RangeStatus.low => 'BAS (< 550 tr/m)',
            RangeStatus.normal => 'ZONE OK (< ${shift.toStringAsFixed(0)})',
            RangeStatus.high => 'ZONE ROUGE !',
            RangeStatus.unknown => 'CAPTEUR G28',
          },
          status: st,
        );

      case TileSlotType.speed:
        final spd = c.data.get(EngineRole.speed);
        final st = spd == null ? RangeStatus.unknown : _check(spd, 0, 135);
        return _metricTile(
          label: 'VITESSE',
          value: _f(spd, 0),
          unit: 'km/h',
          sub: c.tripAvgSpeed > 0 ? 'MOY. ${c.tripAvgSpeed.toStringAsFixed(0)} km/h' : 'VITESSE ECU',
          status: st,
        );

      case TileSlotType.maf:
        final maf = c.data.get(EngineRole.maf);
        final thr = c.data.get(EngineRole.throttle);
        if (prof.isDiesel) {
          final st = _check(maf, 180, 1150);
          return _metricTile(
            label: 'DÉBIT AIR (MAF)',
            value: _f(maf, 0),
            unit: 'mg/h',
            sub: 'COTE 180–1150 mg/h',
            status: st,
          );
        }
        final maxMaf = prof.hasTurbo ? 160.0 : 85.0;
        final st = _check(maf, 2.0, maxMaf);
        return _metricTile(
          label: 'DÉBIT AIR',
          value: _f(maf, 1),
          unit: 'g/s',
          sub: thr != null ? 'PAP ${thr.toStringAsFixed(1)}° • G70' : 'COTE 2–${maxMaf.toStringAsFixed(0)} g/s',
          status: st,
        );

      case TileSlotType.throttle:
        final thr = c.data.get(EngineRole.throttle);
        final st = _check(thr, 2.0, 80.0);
        return _metricTile(
          label: prof.isDiesel ? 'PÉDALE' : 'PAPILLON',
          value: _f(thr, 1),
          unit: prof.isDiesel ? '%' : '°',
          sub: switch (st) {
            RangeStatus.low => 'FERMÉ (< 2)',
            RangeStatus.normal => 'NORMAL (2–80)',
            RangeStatus.high => 'PLEIN GAZ (> 80)',
            RangeStatus.unknown => 'COTE 2–80',
          },
          status: st,
        );

      case TileSlotType.load:
        final load = c.data.get(EngineRole.load);
        final st = _check(load, 10, 88);
        return _metricTile(
          label: 'CHARGE MOTEUR',
          value: _f(load, 0),
          unit: '%',
          sub: switch (st) {
            RangeStatus.low => 'FAIBLE (< 10%)',
            RangeStatus.normal => 'NORMAL (10–88%)',
            RangeStatus.high => 'PLEINE CHARGE',
            RangeStatus.unknown => 'COTE 10–88%',
          },
          status: st,
        );

      case TileSlotType.boost:
        final map = c.data.get(EngineRole.map);
        if (prof.hasTurbo || prof.isDiesel) {
          final boostBar = map != null ? (map - 1013.0) / 1000.0 : null;
          final maxBar = prof.isDiesel ? 1.55 : 1.35;
          final st = _check(boostBar, prof.isDiesel ? -0.1 : -0.75, maxBar);
          return _metricTile(
            label: prof.isDiesel ? 'TURBO (GRP 11)' : 'TURBO (GRP 115)',
            value: boostBar == null ? '—' : '${boostBar >= 0 ? '+' : ''}${boostBar.toStringAsFixed(2)}',
            unit: 'bar',
            sub: map != null ? '${map.toStringAsFixed(0)} mbar abs.' : 'COTE 0.0–$maxBar bar',
            status: st,
          );
        }
        final st = _check(map, 250, 950);
        return _metricTile(
          label: 'COLLECTEUR',
          value: _f(map, 0),
          unit: 'mbar',
          sub: switch (st) {
            RangeStatus.low => 'DÉPRESSION (< 250)',
            RangeStatus.normal => 'NORMAL (250–950)',
            RangeStatus.high => 'PLEINE CHARGE (> 950)',
            RangeStatus.unknown => 'COTE 250–950',
          },
          status: st,
        );

      case TileSlotType.lph:
        final st = (c.rpm ?? 0) > 300 ? _check(c.lph, prof.idleLphMin, 18.0) : RangeStatus.unknown;
        return _metricTile(
          label: 'DÉBIT DIRECT',
          value: c.lph.toStringAsFixed(1),
          unit: 'L/h',
          sub: 'RALENTI ${prof.idleLphMin.toStringAsFixed(1)}–${prof.idleLphMax.toStringAsFixed(1)} L/h',
          status: st,
        );

      case TileSlotType.avgSpeed:
        final avg = c.tripAvgSpeed;
        return _metricTile(
          label: 'VITESSE MOY.',
          value: avg > 0 ? avg.toStringAsFixed(0) : '—',
          unit: 'km/h',
          sub: 'TRAJET ${c.s.tripKm.toStringAsFixed(1)} km',
          status: avg > 0 ? RangeStatus.normal : RangeStatus.unknown,
        );
    }
  }

  // ------------------------------------------------------------------ ORDINATEUR DE TRAJET
  Widget _tripRow() {
    final secs = c.s.tripSeconds.round();
    final dur = '${secs ~/ 3600}h${((secs % 3600) ~/ 60).toString().padLeft(2, '0')}';
    final avgStatus = _check(c.tripAvgL100 > 0 ? c.tripAvgL100 : null, 4.5, 10.5);

    return LayoutBuilder(
      builder: (context, box) {
        final tightH = box.maxHeight < 95;
        final tightW = box.maxWidth < 360;
        final divMargin = tightW ? 5.0 : 10.0;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: tightW ? 10 : 14, vertical: tightH ? 5 : 9),
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
                  const SizedBox(width: 7),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ORDINATEUR DE TRAJET',
                        maxLines: 1,
                        style: Retro.title(12, c: Retro.titleWhite),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: c.resetTrip,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: tightW ? 7 : 10, vertical: tightH ? 2 : 3),
                      decoration: BoxDecoration(
                        color: Retro.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Retro.border, width: 1),
                      ),
                      child: Text('REMISE À ZÉRO', style: Retro.title(9.5, c: Retro.white)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tightH ? 3 : 6),
              Expanded(
                child: Row(
                  children: [
                    _tripStat('DISTANCE', _f(c.s.tripKm, 1), 'km', RangeStatus.normal),
                    _verticalDivider(divMargin),
                    _tripStat('DURÉE', dur, '', RangeStatus.normal),
                    _verticalDivider(divMargin),
                    _tripStat(
                      'MOYENNE',
                      c.tripAvgL100 > 0 ? c.tripAvgL100.toStringAsFixed(1) : '—',
                      'L/100',
                      avgStatus,
                    ),
                    _verticalDivider(divMargin),
                    _tripStat('CARBURANT', c.s.tripFuel.toStringAsFixed(2), 'L', RangeStatus.normal),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _verticalDivider([double marginH = 10]) => Container(
        width: 1,
        margin: EdgeInsets.symmetric(horizontal: marginH, vertical: 3),
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
          mainAxisSize: MainAxisSize.min,
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
    required Widget Function(bool compactH) builder,
  }) {
    final borderCol = Retro.borderColor(status);
    final topBarCol = switch (status) {
      RangeStatus.low => Retro.blue,
      RangeStatus.high => Retro.red,
      RangeStatus.normal => c.s.profile.accent,
      RangeStatus.unknown => c.s.profile.accent,
    };

    return LayoutBuilder(
      builder: (context, box) {
        final narrowCard = box.maxWidth < 235;
        final compactH = box.maxHeight < 145;
        final stackHeader = narrowCard && !compactH;

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
                  padding: EdgeInsets.fromLTRB(
                    narrowCard ? 10 : 12,
                    compactH ? 6 : 9,
                    narrowCard ? 10 : 12,
                    compactH ? 6 : 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (stackHeader) ...[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: Retro.title(13, c: Retro.titleWhite),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _statusBadge(spec, status),
                          ),
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  style: Retro.title(12.5, c: Retro.titleWhite),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              flex: 5,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: _statusBadge(spec, status),
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: compactH ? 2 : 4),
                      Expanded(child: builder(compactH)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: status == RangeStatus.normal || status == RangeStatus.unknown ? Retro.border : col),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.3),
      ),
    );
  }

  Widget _segmentedBar({
    required double fraction,
    required int segments,
    required Color activeColor,
    double height = 6,
  }) {
    final activeCount = (fraction.clamp(0.0, 1.0) * segments).round();
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SegmentedBarPainter(
            segments: segments,
            activeCount: activeCount,
            activeColor: activeColor,
          ),
        ),
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

    return LayoutBuilder(
      builder: (context, box) {
        final tightW = box.maxWidth < 110;
        final tightH = box.maxHeight < 95;
        final hPad = tightW ? 7.0 : 10.0;

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
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: tightH ? 3.5 : 6),
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
                    const SizedBox(width: 5),
                    Container(
                      width: 7.5,
                      height: 7.5,
                      decoration: BoxDecoration(color: dotCol, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
              // Valeur + Sous-texte de cote
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, tightH ? 3 : 6, hPad, tightH ? 4 : 7),
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
                                const SizedBox(width: 4),
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
      },
    );
  }

  // ------------------------------------------------------------------ BARRE D'ACTIONS BAS
  Widget _bottomBar(BuildContext context, double maxWidth, bool compactH) {
    final carOn = c.mode == SourceMode.car;
    final simOn = c.mode == SourceMode.sim;
    final compactW = maxWidth < 360;
    final gap = compactW ? 5.0 : 8.0;
    final btnH = compactH ? 32.0 : 36.0;

    return RepaintBoundary(
      child: Container(
        height: compactH ? 42 : 50,
        padding: EdgeInsets.symmetric(horizontal: compactW ? 6 : 10, vertical: compactH ? 5 : 7),
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
                height: btnH,
                compactW: compactW,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _actionBtn(
                simOn ? 'STOP SIMU' : 'SIMULATION',
                simOn ? c.stopSim : c.startSim,
                active: simOn,
                height: btnH,
                compactW: compactW,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _actionBtn(
                'PLEIN',
                () => showRefuelDialog(context, c),
                height: btnH,
                compactW: compactW,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _actionBtn(
                'DIAGNOSTIC',
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiagScreen(c: c))),
                height: btnH,
                compactW: compactW,
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: compactW ? 36 : 40,
              height: btnH,
              child: ListenableBuilder(
                listenable: updater ?? c,
                builder: (context, _) {
                  final hasUpdate = updater?.availableUpdate != null;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SettingsScreen(c: c, updater: updater)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Retro.surface,
                            side: BorderSide(color: hasUpdate ? c.s.profile.accent : Retro.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 18, color: Retro.white),
                        ),
                      ),
                      if (hasUpdate)
                        Positioned(
                          right: 3,
                          top: 3,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.s.profile.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Retro.bg, width: 1.2),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    VoidCallback onTap, {
    bool active = false,
    double height = 36,
    bool compactW = false,
  }) {
    final accent = c.s.profile.accent;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Retro.white,
          backgroundColor: active ? accent : Retro.surface,
          side: BorderSide(color: active ? accent : Retro.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.symmetric(horizontal: compactW ? 4 : 6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
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

class _SegmentedBarPainter extends CustomPainter {
  const _SegmentedBarPainter({
    required this.segments,
    required this.activeCount,
    required this.activeColor,
  });

  final int segments;
  final int activeCount;
  final Color activeColor;

  static const _inactiveColor = Color(0xFF1F212A);

  @override
  void paint(Canvas canvas, Size size) {
    if (segments <= 0 || size.width <= 0 || size.height <= 0) return;
    const gap = 2.0;
    final segW = (size.width - gap * (segments - 1)) / segments;
    if (segW <= 0) return;
    final activePaint = Paint()..color = activeColor;
    final inactivePaint = Paint()..color = _inactiveColor;
    const radius = Radius.circular(1.5);
    for (var i = 0; i < segments; i++) {
      final left = i * (segW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, segW, size.height), radius),
        i < activeCount ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedBarPainter old) =>
      old.activeCount != activeCount || old.activeColor != activeColor || old.segments != segments;
}
