import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/engine_data.dart';
import '../models/vehicle_profile.dart';
import 'kline_service.dart';
import 'settings.dart';
import 'simulator.dart';
import 'vag_decoder.dart';

enum SourceMode { none, sim, car }

class FaultCode {
  final int code;
  final int status;
  FaultCode(this.code, this.status);
}

/// Cerveau de l'appli : source de donnees (voiture / simulateur) et ordinateur de bord (sans GPS).
class DashboardController extends ChangeNotifier {
  DashboardController(this.s);

  final AppSettings s;
  final KLineService kline = KLineService();
  final EngineData data = EngineData();
  final Simulator sim = Simulator();

  SourceMode mode = SourceMode.none;
  String connState = 'idle';
  String status = 'Déconnecté';
  String? clusterId;
  String? ecuId;
  final List<String> logs = [];

  // blocs de mesures du calculateur moteur (adresse 0x01)
  final Map<int, List<VagValue>> groups = {};
  final Map<int, bool> groupOk = {};
  final Map<int, String> groupRawInfo = {};
  final Map<int, List<int>> groupF4Raw = {};
  bool isSimosF4 = false;
  Map<EngineRole, String> mapping = {};
  bool discovering = false;
  int? exploreGroup;
  List<FaultCode>? faults;
  bool readingFaults = false;
  bool serviceBusy = false;
  String? serviceMessage;
  double? throttleProgress; // 0.0 .. 1.0 pendant l'alignement papillon
  List<VagValue> throttleValues = [];

  int _address = 0x01;
  int _clusterEvents = 0;
  Timer? _clusterTimeout;

  // valeurs calculees
  double speed = 0;
  double? rpm;
  double lph = 0;
  double? l100Inst;
  bool isCutoff = false;

  Timer? _tick;
  Timer? _logSaveTimer;
  Timer? _logUiTimer;
  StreamSubscription? _ev;
  final Stopwatch _sw = Stopwatch();
  double _saveAcc = 0;
  double _carUiAcc = 0;
  int _lastClockMinute = -1;
  Map<int, List<(EngineRole, int)>> _groupRoleLookup = {};

  List<int> get discoveryGroups => s.profile.discoveryGroups;

  // ------------------------------------------------------------------ cycle de vie

  Future<void> init() async {
    if (s.savedLogs.isNotEmpty) {
      logs.addAll(s.savedLogs);
    }
    _lastClockMinute = DateTime.now().minute;
    _ev = kline.events.listen(_onEvent);
    _sw.start();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
    if (KLineService.supported && s.autoConnect) {
      try {
        final devs = await kline.listDevices();
        if (devs.isNotEmpty) await connectCar();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _clusterTimeout?.cancel();
    _logUiTimer?.cancel();
    if (_logSaveTimer != null) {
      _logSaveTimer!.cancel();
      _logSaveTimer = null;
      s.saveLogs(logs);
    }
    _ev?.cancel();
    s.saveMemories();
    super.dispose();
  }

  void _scheduleLogSave() {
    _logSaveTimer ??= Timer(const Duration(seconds: 2), () {
      _logSaveTimer = null;
      s.saveLogs(logs);
    });
  }

  void _notifyLogsThrottled() {
    _logUiTimer ??= Timer(const Duration(milliseconds: 250), () {
      _logUiTimer = null;
      notifyListeners();
    });
  }

  void _rebuildGroupLookup() {
    final map = <int, List<(EngineRole, int)>>{};
    mapping.forEach((role, key) {
      final parts = key.split(':');
      if (parts.length != 2) return;
      final g = int.tryParse(parts[0]);
      final idx = int.tryParse(parts[1]);
      if (g != null && idx != null) {
        (map[g] ??= []).add((role, idx));
      }
    });
    _groupRoleLookup = map;
  }

  void _log(String m) {
    final t = DateTime.now();
    final ts =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    logs.add('$ts  $m');
    if (logs.length > 300) logs.removeRange(0, logs.length - 300);
    _scheduleLogSave();
  }

  void clearLogs() {
    _logSaveTimer?.cancel();
    _logSaveTimer = null;
    logs.clear();
    s.saveLogs(logs);
    notifyListeners();
  }

  String buildDiagReport() {
    final sb = StringBuffer();
    sb.writeln('=== RAPPORT DIAGNOSTIC OLDBOARD (${s.profile.name}) ===');
    sb.writeln('Date : ${DateTime.now().toIso8601String()}');
    sb.writeln('État : $status ($connState)');
    sb.writeln('Calculateur : ${ecuId ?? "Non identifié"}');
    sb.writeln('');
    sb.writeln('--- AFFECTATION DES RÔLES ---');
    for (final r in EngineRole.values) {
      sb.writeln('${r.label} (${r.name}) : ${mapping[r] ?? "non affecté"} (val=${data.get(r)})');
    }
    sb.writeln('');
    sb.writeln('--- BILAN MÉCANIQUE TRAJET (MIN / MAX) ---');
    sb.writeln('Régime max : ${s.maxRpm.toStringAsFixed(0)} tr/min');
    sb.writeln('Débit air MAF max : ${s.maxMaf.toStringAsFixed(1)} g/s');
    sb.writeln('Papillon min / max : ${s.minThrottle >= 0 ? s.minThrottle.toStringAsFixed(1) : "--"} ° / ${s.maxThrottle.toStringAsFixed(1)} °');
    sb.writeln('Temp. moteur max : ${s.maxCoolant.toStringAsFixed(0)} °C');
    sb.writeln('Tension batterie min : ${s.minBattery > 0 ? s.minBattery.toStringAsFixed(2) : "--"} V');
    sb.writeln('Lambda min / max : ${s.minLambda.toStringAsFixed(1)} % / +${s.maxLambda.toStringAsFixed(1)} %');
    sb.writeln('');
    sb.writeln('--- BLOCS DE MESURES BRUTS ---');
    sb.writeln('Format calculateur moteur : ${isSimosF4 ? "Simos 2.1 (0xF4 - 4 octets bruts)" : "Standard (0xE7 - triplets)"}');
    final gKeys = {...groups.keys, ...groupOk.keys, ...groupRawInfo.keys, ...groupF4Raw.keys}.toList()..sort();
    for (final g in gKeys) {
      final vals = groups[g] ?? [];
      final cells = vals
          .map((v) => '[f=0x${v.formula.toRadixString(16).padLeft(2, '0')} a=${v.a} b=${v.b} => ${v.display}]')
          .join(' ');
      final f4 = groupF4Raw[g];
      final f4Str = (f4 != null && f4.isNotEmpty) ? ' | ${formatF4Raw(f4)}' : '';
      final raw = groupRawInfo[g];
      sb.writeln(
        'Groupe ${g.toString().padLeft(3, '0')} (ok=${groupOk[g]}) : '
        '${cells.isNotEmpty ? cells : "aucune cellule"}$f4Str${raw != null && raw.isNotEmpty ? " | $raw" : ""}',
      );
    }
    if (faults != null) {
      sb.writeln('');
      sb.writeln('--- CODES DÉFAUT ---');
      for (final f in faults!) {
        sb.writeln('Code ${f.code.toString().padLeft(5, '0')} (statut=${f.status})');
      }
    }
    sb.writeln('');
    sb.writeln('--- JOURNAL KWP1281 ---');
    for (final l in logs) {
      sb.writeln(l);
    }
    return sb.toString();
  }

  // ------------------------------------------------------------------ sources

  void startSim() {
    if (mode == SourceMode.car) disconnectCar();
    data.clear();
    sim.reset();
    mode = SourceMode.sim;
    status = 'Simulation';
    connState = 'sim';
    notifyListeners();
  }

  void stopSim() {
    if (mode != SourceMode.sim) return;
    mode = SourceMode.none;
    data.clear();
    status = 'Déconnecté';
    connState = 'idle';
    notifyListeners();
  }

  Future<void> connectCar() async {
    if (!KLineService.supported) {
      status = 'Câble USB : uniquement sur Android';
      notifyListeners();
      return;
    }
    stopSim();
    mode = SourceMode.car;
    data.clear();
    groups.clear();
    groupOk.clear();
    groupRawInfo.clear();
    groupF4Raw.clear();
    isSimosF4 = false;
    faults = null;
    exploreGroup = null;
    status = 'Connexion…';
    connState = 'connecting';
    _log('--- Nouvelle tentative de connexion USB KKL ---');
    notifyListeners();

    if (s.readClusterFuel) {
      _address = 0x17;
      _clusterEvents = 0;
      _log('Lecture jauge carburant au combiné (0x17)');
      _clusterTimeout?.cancel();
      _clusterTimeout = Timer(const Duration(seconds: 20), () {
        if (_address == 0x17) {
          _log('Combiné muet, passage au calculateur moteur (0x01)');
          _goEngine(initial: false);
        }
      });
      final ok = await kline.connect(0x17, [2]);
      if (!ok) mode = SourceMode.none;
    } else {
      await _goEngine(initial: true);
    }
  }

  Future<void> _goEngine({required bool initial}) async {
    _clusterTimeout?.cancel();
    _address = 0x01;
    discovering = true;
    groups.clear();
    groupOk.clear();
    groupRawInfo.clear();
    groupF4Raw.clear();
    isSimosF4 = false;
    if (initial) {
      final ok = await kline.connect(0x01, discoveryGroups);
      if (!ok) mode = SourceMode.none;
    } else {
      await kline.switchAddress(0x01, discoveryGroups);
    }
    notifyListeners();
  }

  Future<void> disconnectCar() async {
    _clusterTimeout?.cancel();
    await kline.disconnect();
    mode = SourceMode.none;
    status = 'Déconnecté';
    connState = 'idle';
    data.clear();
    notifyListeners();
  }

  Future<void> readFaults() async {
    if (mode == SourceMode.sim) {
      faults = [];
      _log('[SIMU] Lecture codes défaut : 0 défaut');
      notifyListeners();
      return;
    }
    if (mode != SourceMode.car || connState != 'connected' || _address != 0x01) return;
    readingFaults = true;
    notifyListeners();
    await kline.readFaults();
  }

  Future<void> clearFaults() async {
    if (mode == SourceMode.sim) {
      faults = [];
      serviceMessage = 'Codes défaut moteur effacés (Simulation) ✔';
      _log('[SIMU] Codes défaut moteur effacés');
      notifyListeners();
      return;
    }
    if (mode != SourceMode.car || connState != 'connected' || _address != 0x01) return;
    serviceBusy = true;
    serviceMessage = 'Effacement des codes défaut en cours…';
    notifyListeners();
    await kline.clearFaults();
  }

  Future<void> resetAdaptations() async {
    if (mode == SourceMode.sim) {
      serviceMessage = 'Auto-adaptations moteur (Canal 00) remises à zéro (Simulation) ✔';
      _log('[SIMU] Auto-adaptations moteur remises à zéro');
      notifyListeners();
      return;
    }
    if (mode != SourceMode.car || connState != 'connected' || _address != 0x01) return;
    serviceBusy = true;
    serviceMessage = 'Remise à zéro des auto-adaptations (Canal 00)…';
    notifyListeners();
    await kline.resetAdaptations();
  }

  Future<void> startThrottleAlign() async {
    final grp = s.profile.throttleBasicGroup ?? 98;
    if (mode == SourceMode.sim) {
      serviceBusy = true;
      throttleProgress = 0.0;
      serviceMessage = 'Calibrage boîtier papillon (Groupe ${grp.toString().padLeft(3, '0')}) en cours…';
      notifyListeners();
      for (var i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 350));
        throttleProgress = i / 10;
        notifyListeners();
      }
      serviceBusy = false;
      throttleProgress = null;
      serviceMessage = 'Calibrage du boîtier papillon (Groupe ${grp.toString().padLeft(3, '0')}) terminé ✔';
      _log('[SIMU] Calibrage boîtier papillon Groupe ${grp.toString().padLeft(3, '0')} terminé');
      notifyListeners();
      return;
    }
    if (mode != SourceMode.car || connState != 'connected' || _address != 0x01) return;
    serviceBusy = true;
    throttleProgress = 0.0;
    throttleValues = [];
    serviceMessage = 'Alignement boîtier papillon (Groupe ${grp.toString().padLeft(3, '0')}) en cours…';
    notifyListeners();
    await kline.throttleAlign(group: grp);
  }

  /// Lecture en continu d'un seul groupe (exploration), ou retour au tableau de bord si null.
  Future<void> explore(int? group) async {
    exploreGroup = group;
    if (group != null) {
      await kline.setGroups([group]);
    } else {
      await kline.setGroups(_schedule());
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ evenements natifs

  void _onEvent(Map<dynamic, dynamic> e) {
    final type = e['type'];
    switch (type) {
      case 'log':
        _log(e['msg'] as String);
        _notifyLogsThrottled();
        return;
      case 'state':
        connState = e['state'] as String;
        final msg = e['msg'] as String?;
        status = switch (connState) {
          'connecting' => 'Ouverture câble…',
          'init' => _address == 0x17 ? 'Connexion combiné…' : 'Connexion moteur…',
          'connected' => _address == 0x17 ? 'Lecture combiné…' : 'Connecté',
          'error' => 'Erreur : ${msg ?? ''}',
          'disconnected' => 'Déconnecté',
          _ => connState,
        };
        if (msg != null) _log('[$connState] $msg');
        if (connState == 'error' || connState == 'disconnected') {
          readingFaults = false;
          serviceBusy = false;
          throttleProgress = null;
        }
        if (connState == 'disconnected' && mode == SourceMode.car) mode = SourceMode.none;
      case 'connected':
        final addr = e['address'] as int;
        final idStr = e['ecuId'] as String?;
        if (addr == 0x17) clusterId = idStr;
        if (addr == 0x01) ecuId = idStr;
        _log('Connecté 0x${addr.toRadixString(16)} @${e['baud']} bauds ($idStr)');
        if (s.autoDetectVehicle) {
          final detected = VehicleProfile.detectFromIds(clusterId: clusterId, ecuId: ecuId);
          if (detected != null && detected.id != s.profileId) {
            _log('Détection auto véhicule : ${detected.name} (${detected.ecuLabel})');
            s.applyProfile(detected);
            // Si on vient de se connecter au moteur (0x01), basculer immédiatement sur les groupes de découverte du profil détecté
            if (addr == 0x01 && discovering) {
              kline.setGroups(detected.discoveryGroups);
            }
          }
        }
      case 'group':
        _onGroup(e);
      case 'faults':
        readingFaults = false;
        final list = (e['codes'] as List).cast<Map<dynamic, dynamic>>();
        faults = list.map((m) => FaultCode(m['code'] as int, m['status'] as int)).toList();
        _log('${faults!.length} code(s) défaut');
      case 'throttleProgress':
        final step = e['step'] as int? ?? 0;
        final total = e['total'] as int? ?? 25;
        throttleProgress = total > 0 ? step / total : 0;
        serviceMessage = e['msg'] as String?;
        final rawVals = (e['values'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];
        throttleValues = rawVals.map((m) => decodeVag(m['f'] as int, m['a'] as int, m['b'] as int)).toList();
      case 'serviceDone':
        serviceBusy = false;
        throttleProgress = null;
        serviceMessage = e['msg'] as String?;
        if (serviceMessage != null) _log(serviceMessage!);
    }
    notifyListeners();
  }

  void _onGroup(Map<dynamic, dynamic> e) {
    final addr = e['address'] as int;
    final g = e['group'] as int;
    final ok = e['ok'] as bool;
    final isRawF4 = (e['isRawF4'] as bool?) ?? false;
    final rawBytes = ((e['rawBytes'] as List?) ?? const []).cast<int>();
    final rawTx = (e['rawTx'] as String?) ?? '';
    final rawRx = (e['rawRx'] as String?) ?? '';
    final err = e['error'] as String?;

    final List<VagValue> vals;
    if (addr == 0x01 && isRawF4) {
      isSimosF4 = true;
      groupF4Raw[g] = rawBytes;
      vals = decodeSimos21F4(g, rawBytes);
    } else {
      vals = (e['values'] as List)
          .cast<Map<dynamic, dynamic>>()
          .map((m) => decodeVag(m['f'] as int, m['a'] as int, m['b'] as int))
          .toList();
    }

    if (addr == 0x17) {
      if (_address != 0x17) return; // Ignore tout bloc 0x17 résiduel si la bascule vers 0x01 est déjà lancée
      _clusterEvents++;
      var gotFuel = false;
      for (final v in vals) {
        if (v.formula == 0x13 && v.value != null && v.value! >= 0 && v.value! <= s.tankCapacity + 5) {
          s.fuelRemaining = math.min(v.value!, s.tankCapacity);
          s.saveMemories();
          _log('Jauge combiné (groupe $g) : ${v.value!.toStringAsFixed(1)} L');
          gotFuel = true;
        }
      }
      if (gotFuel || _clusterEvents >= 3) {
        if (!gotFuel) _log('Fin lecture combiné, bascule sur calculateur moteur');
        _goEngine(initial: false);
      }
      return;
    }

    groupOk[g] = ok;
    if (ok && vals.isNotEmpty) {
      groups[g] = vals;
    } else {
      groups.putIfAbsent(g, () => vals);
    }
    groupRawInfo[g] = [
      if (err != null && err.isNotEmpty) 'err="$err"',
      if (rawTx.isNotEmpty) 'TX=[$rawTx]',
      if (rawRx.isNotEmpty) 'RX=[$rawRx]',
    ].join(' ');

    if (discovering && ok && vals.isNotEmpty) {
      _autoMap(silent: true);
    }

    // En mode Simos 2.1 (0xF4), le champ 0 des groupes 1, 2, 3, 4 et 5 contient toujours le régime (b0 * 32),
    // le champ 2 du groupe 5 contient la température moteur G62, et le champ 3 du groupe 2 contient le drapeau de coupure (0x08)
    if (isSimosF4 && ok && rawBytes.length >= 4) {
      if ((g == 1 || g == 2 || g == 3 || g == 4 || g == 5) && !s.roleOverrides.containsKey(EngineRole.rpm.name)) {
        data.set(EngineRole.rpm, rawBytes[0] * 32.0);
      }
      if (g == 5 && !s.roleOverrides.containsKey(EngineRole.coolant.name)) {
        data.set(EngineRole.coolant, (rawBytes[2] * 0.75) - 48.0);
      }
      if (g == 2) {
        data.set(EngineRole.cutoff, (rawBytes[3] & 0x08) != 0 ? 1.0 : 0.0);
      }
    }

    final entries = _groupRoleLookup[g];
    if (entries != null) {
      for (final (role, idx) in entries) {
        if (idx < vals.length && vals[idx].value != null) data.set(role, vals[idx].value!);
      }
    }

    if (discovering && discoveryGroups.every(groupOk.containsKey)) {
      discovering = false;
      _autoMap(silent: false);
      final sched = _schedule();
      _log('Groupes lus en continu : ${sched.toSet().join(", ")}');
      kline.setGroups(sched);
    }
  }

  // ------------------------------------------------------------------ identification des valeurs

  static const Map<EngineRole, String> _simos21DefaultMap = {
    EngineRole.rpm: '1:0',
    EngineRole.coolant: '1:1',
    EngineRole.lambda: '7:1',
    EngineRole.injection: '2:1',
    EngineRole.speed: '2:2',
    EngineRole.load: '3:1',
    EngineRole.throttle: '3:2',
    EngineRole.maf: '4:2',
    EngineRole.battery: '5:1',
    EngineRole.intakeAir: '5:3',
  };

  void _autoMap({bool silent = false}) {
    final found = <EngineRole, String>{};

    if (isSimosF4) {
      // Mapping dédié Simos 2.1 (06A906019AM - blocs 0xF4 de 4 octets)
      _simos21DefaultMap.forEach((role, key) {
        final g = int.parse(key.split(':')[0]);
        if (groupOk[g] != false) {
          found[role] = key;
        }
      });
    } else {
      // 1. Appliquer d'abord le mapping Ross-Tech calibre du profil (ME7.5, M3.8.3, Simos 3, Marelli 4LV, EDC15 TDI)
      // si la cellule correspondante a bien repondu avec une valeur numerique
      s.profile.preferredE7Map.forEach((role, key) {
        final parts = key.split(':');
        final g = int.parse(parts[0]);
        final idx = int.parse(parts[1]);
        final vals = groups[g];
        if (groupOk[g] == true && vals != null && idx < vals.length && vals[idx].value != null) {
          found[role] = key;
        }
      });

      // 2. Completer les roles manquants par auto-detection universelle des formules 0xE7
      final keys = groups.keys.toList()..sort();

      String? first(bool Function(VagValue v) test,
          {List<int>? prefer, Set<String>? exclude, bool lastInGroup = false}) {
        final order = [...?prefer, ...keys.where((k) => !(prefer?.contains(k) ?? false))];
        for (final g in order) {
          final vals = groups[g];
          if (vals == null) continue;
          final idxs = List.generate(vals.length, (i) => i);
          for (final i in lastInGroup ? idxs.reversed : idxs) {
            final k = '$g:$i';
            if (exclude != null && exclude.contains(k)) continue;
            if (test(vals[i])) return k;
          }
        }
        return null;
      }

      void putIfMissing(EngineRole r, String? k) {
        if (k != null && !found.containsKey(r)) found[r] = k;
      }

      putIfMissing(EngineRole.rpm, first((v) => v.formula == 0x01));
      putIfMissing(EngineRole.speed, first((v) => v.formula == 0x07));
      final coolant = found[EngineRole.coolant] ?? first((v) => v.formula == 0x05, prefer: [1]);
      putIfMissing(EngineRole.coolant, coolant);
      final iat = first((v) => v.formula == 0x05, exclude: {?coolant});
      putIfMissing(EngineRole.intakeAir, iat);
      putIfMissing(EngineRole.battery,
          first((v) => (v.formula == 0x06 || v.formula == 0x15) && v.value != null && v.value! > 8 && v.value! < 17));
      putIfMissing(EngineRole.injection, first((v) => v.formula == 0x0F || v.formula == 0x16, lastInGroup: true));
      putIfMissing(EngineRole.map, first((v) => v.formula == 0x12, prefer: [115, 11, 3], lastInGroup: true));
      putIfMissing(EngineRole.maf, first((v) => v.formula == 0x19 || v.formula == 0x35 || v.formula == 0x31));
      putIfMissing(EngineRole.throttle, first((v) => v.formula == 0x03 || v.formula == 0x17 || v.formula == 0x21));
      putIfMissing(EngineRole.load, first((v) => v.formula == 0x21 || v.formula == 0x02));
      putIfMissing(EngineRole.lambda, first((v) => v.formula == 0x14));
      putIfMissing(EngineRole.fuelLph, first((v) => v.formula == 0x23));
      putIfMissing(EngineRole.fuelMg, first((v) => v.formula == 0x27));
    }

    // affectations manuelles (ecran Diagnostic)
    s.roleOverrides.forEach((name, key) {
      final r = EngineRole.values.where((e) => e.name == name);
      if (r.isEmpty) return;
      if (key.isEmpty) {
        found.remove(r.first);
      } else {
        found[r.first] = key;
      }
    });

    mapping = found;
    _rebuildGroupLookup();
    if (!silent) {
      found.forEach((r, k) => _log('${r.label} → groupe ${k.replaceAll(":", " champ ")}'));
    }
  }

  void assignRole(EngineRole role, String? key) {
    s.roleOverrides[role.name] = key ?? '';
    s.changed();
    if (key == null) {
      mapping.remove(role);
    } else {
      mapping[role] = key;
    }
    _rebuildGroupLookup();
    if (exploreGroup == null && mode == SourceMode.car && !discovering) kline.setGroups(_schedule());
    notifyListeners();
  }

  /// Groupes rapides (regime, vitesse, injection, lambda...) lus a chaque cycle, groupes lents intercales.
  List<int> _schedule() {
    if (isSimosF4) {
      // Rotation continue sur les groupes utiles du Simos 2.1 : [1, 2, 3, 4, 5, 7]
      final base = <int>{1, 2, 3, 4, 5, 7};
      mapping.forEach((_, k) {
        final g = int.tryParse(k.split(':')[0]);
        if (g != null && groupOk[g] != false) base.add(g);
      });
      return base.toList()..sort();
    }
    const fastRoles = {
      EngineRole.rpm,
      EngineRole.speed,
      EngineRole.injection,
      EngineRole.lambda,
      EngineRole.map,
      EngineRole.maf,
      EngineRole.fuelLph,
      EngineRole.fuelMg,
    };
    final fast = <int>{};
    final slow = <int>{};
    mapping.forEach((r, k) {
      final g = int.parse(k.split(':')[0]);
      (fastRoles.contains(r) ? fast : slow).add(g);
    });
    slow.removeAll(fast);
    final f = fast.toList()..sort();
    final sl = slow.toList()..sort();
    if (f.isEmpty && sl.isEmpty) return [1];
    if (sl.isEmpty) return f;
    if (f.isEmpty) return sl;
    return [for (final g in sl) ...[...f, g]];
  }

  // ------------------------------------------------------------------ ordinateur de bord

  /// Detecte la coupure d'injection en deceleration (frein moteur / Schubabschaltung).
  /// - Simos 2.1 (0xF4) : drapeau officiel bit 3 (0x08) de l'octet b3 du Groupe 002.
  /// - Diesel TDI (EDC15) : quantite injectee == 0.0 mg/coup (ou L/h == 0.0) a > 1200 tr/min.
  /// - Essence 0xE7 / Simu : temps d'injection < 0.05 ms a > 1300 tr/min.
  bool _detectOverrunCutoff() {
    final r = data.get(EngineRole.rpm);
    if (r == null || r <= 300) return false;
    final ecuCutoff = data.get(EngineRole.cutoff);
    if (ecuCutoff != null) return ecuCutoff >= 0.5;
    if (s.profile.isDiesel && r > 1200) {
      final mg = data.get(EngineRole.fuelMg);
      if (mg != null && mg < 0.2) return true;
      final dlph = data.get(EngineRole.fuelLph);
      if (dlph != null && dlph < 0.05) return true;
    }
    final inj = data.get(EngineRole.injection);
    if (r > 1300 && inj != null && inj < 0.05) return true;
    return false;
  }

  double? computeLph() {
    final r = data.get(EngineRole.rpm);
    if (r == null || r < 300) return r == null ? null : 0;
    if (isCutoff) return 0.0;

    // Mode Diesel (1.9 TDI EDC15 / MSA15) : debit direct L/h (0x23) ou quantite injectee mg/coup (0x27)
    if (s.profile.isDiesel) {
      final directLph = data.get(EngineRole.fuelLph);
      if (directLph != null) return math.max(0.0, directLph * s.calibration);
      final mg = data.get(EngineRole.fuelMg);
      if (mg != null) {
        // Densite gazole ~835 g/L : mg/coup * nb_cylindres * (rpm / 2) * 60 / 835000
        return math.max(0.0, mg * s.cylinders * (r / 2) * 60 / 835000.0 * s.calibration);
      }
    }

    // Priorite 1 (Essence) : debitmetre d'air MAF (G70, Groupe 4 champ 2) si disponible, corrige par lambda
    final maf = data.get(EngineRole.maf);
    if (maf != null && maf > 0.2) {
      final lam = data.get(EngineRole.lambda) ?? 0.0;
      final corr = (1.0 + lam / 100.0).clamp(0.75, 1.35);
      return (maf / 14.7) * corr * 3600 / 745 * s.calibration;
    }
    final inj = data.get(EngineRole.injection);
    if (inj != null) {
      final eff = math.max(0.0, inj - s.injectorDeadTime);
      // injection sequentielle : 1 injection par cylindre tous les 2 tours
      final ccPerHour = s.cylinders * (r / 2) * 60 * (s.injectorFlow / 60000 * eff);
      return ccPerHour / 1000 * s.calibration;
    }
    final map = data.get(EngineRole.map);
    if (map != null) {
      final iat = data.get(EngineRole.intakeAir) ?? 25;
      final airGs = map * 100 * 0.001595 * (r / 120) * 0.85 / (287.05 * (iat + 273.15)) * 1000;
      return airGs / 14.7 * 3600 / 745 * s.calibration;
    }
    return null;
  }

  double get tripAvgL100 => s.tripKm > 0.3 ? s.tripFuel / s.tripKm * 100 : 0;
  double get tripAvgSpeed => s.tripSeconds > 10 ? s.tripKm / (s.tripSeconds / 3600) : 0;
  double get refL100 => s.fillKm > 30 ? s.fillFuel / s.fillKm * 100 : s.longTermL100;
  double get rangeKm => refL100 > 0 ? s.fuelRemaining / refL100 * 100 : 0;
  bool get lowFuel => s.fuelRemaining < 7.5;

  void _onTick() {
    final dt = _sw.elapsedMicroseconds / 1e6;
    _sw.reset();
    if (dt <= 0 || dt > 2) return;

    // En veille / deconnecte : 0 recalcul et 1 seul rafraichissement par minute pour l'horloge.
    if (mode == SourceMode.none) {
      final min = DateTime.now().minute;
      if (min != _lastClockMinute) {
        _lastClockMinute = min;
        notifyListeners();
      }
      return;
    }

    if (mode == SourceMode.sim) sim.step(dt, data);

    // vitesse lue uniquement depuis le calculateur (0 drain GPS)
    speed = data.get(EngineRole.speed) ?? 0;
    rpm = data.get(EngineRole.rpm);
    isCutoff = _detectOverrunCutoff();
    lph = computeLph() ?? 0;
    final running = rpm != null && rpm! > 300;

    if (running) {
      final dKm = speed * dt / 3600;
      final dL = lph * dt / 3600;
      s.tripKm += dKm;
      s.tripFuel += dL;
      s.tripSeconds += dt;
      s.fillKm += dKm;
      s.fillFuel += dL;
      s.fuelRemaining = math.max(0, s.fuelRemaining - dL);

      // Enregistrement des pics mecaniques (uniquement en connexion reelle voiture)
      if (mode == SourceMode.car) {
        if (rpm! > s.maxRpm) s.maxRpm = rpm!;
        final maf = data.get(EngineRole.maf);
        if (maf != null && maf > s.maxMaf) s.maxMaf = maf;
        final thr = data.get(EngineRole.throttle);
        if (thr != null) {
          if (s.minThrottle < 0 || thr < s.minThrottle) s.minThrottle = thr;
          if (thr > s.maxThrottle) s.maxThrottle = thr;
        }
        final cool = data.get(EngineRole.coolant);
        if (cool != null && cool > s.maxCoolant) s.maxCoolant = cool;
        final batt = data.get(EngineRole.battery);
        if (batt != null && batt > 6.0 && (s.minBattery == 0 || batt < s.minBattery)) {
          s.minBattery = batt;
        }
        final lam = data.get(EngineRole.lambda);
        if (lam != null) {
          if (lam < s.minLambda) s.minLambda = lam;
          if (lam > s.maxLambda) s.maxLambda = lam;
        }
      }

      _saveAcc += dt;
      if (_saveAcc > 10) {
        _saveAcc = 0;
        s.saveMemories();
      }
    }

    // conso instantanee lissee (passage immediat a 0.0 L/100 en coupure frein moteur)
    if (speed > 5 && running) {
      if (isCutoff) {
        l100Inst = 0.0;
      } else {
        final target = lph / speed * 100;
        final a = math.min(1.0, dt / 0.8);
        l100Inst = l100Inst == null ? target : l100Inst! + (target - l100Inst!) * a;
      }
    } else {
      l100Inst = null;
    }

    final min = DateTime.now().minute;
    final minuteChanged = min != _lastClockMinute;
    if (minuteChanged) _lastClockMinute = min;

    if (mode == SourceMode.sim || minuteChanged) {
      notifyListeners();
    } else {
      // En mode voiture, les nouvelles trames KWP notifient deja immediatement via _onEvent :
      // on limite les rafraichissements de lissage pur a ~4 Hz pour economiser CPU/batterie.
      _carUiAcc += dt;
      if (_carUiAcc >= 0.25) {
        _carUiAcc = 0;
        notifyListeners();
      }
    }
  }

  // ------------------------------------------------------------------ actions utilisateur

  void resetTrip() {
    s.tripKm = 0;
    s.tripFuel = 0;
    s.tripSeconds = 0;
    s.maxRpm = 0;
    s.maxMaf = 0;
    s.minThrottle = -1;
    s.maxThrottle = 0;
    s.maxCoolant = 0;
    s.minBattery = 0;
    s.minLambda = 0;
    s.maxLambda = 0;
    s.saveMemories();
    notifyListeners();
  }

  /// Retourne un message decrivant la calibration eventuelle.
  String refuel({required double liters, required bool full}) {
    String msg;
    if (full) {
      if (liters > 0 && s.fillFuel > 5 && s.fillKm > 50) {
        final ratio = clampD(liters / s.fillFuel, 0.6, 1.6);
        s.calibration = clampD(s.calibration * ratio, 0.3, 3);
        s.longTermL100 = liters / s.fillKm * 100;
        msg = 'Calibration ajustée ×${ratio.toStringAsFixed(3)} (conso réelle ${s.longTermL100.toStringAsFixed(1)} L/100)';
      } else {
        msg = 'Plein enregistré';
      }
      s.fuelRemaining = s.tankCapacity;
      s.fillKm = 0;
      s.fillFuel = 0;
    } else {
      s.fuelRemaining = math.min(s.tankCapacity, s.fuelRemaining + liters);
      msg = '${liters.toStringAsFixed(1)} L ajoutés';
    }
    s.changed();
    notifyListeners();
    return msg;
  }
}
