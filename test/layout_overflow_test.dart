import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oldboard/main.dart';
import 'package:oldboard/models/engine_data.dart';
import 'package:oldboard/models/vehicle_profile.dart';
import 'package:oldboard/services/dashboard_controller.dart';
import 'package:oldboard/services/settings.dart';
import 'package:oldboard/services/update_service.dart';
import 'package:oldboard/services/vag_decoder.dart';
import 'package:oldboard/ui/dashboard_screen.dart';
import 'package:oldboard/ui/diag_screen.dart';
import 'package:oldboard/ui/profile_picker_screen.dart';
import 'package:oldboard/ui/settings_screen.dart';
import 'package:oldboard/ui/theme.dart';
import 'package:oldboard/ui/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Matrice complète de tailles Android (petit portrait, compact, POCO 400x869,
/// paysage très bas 640x320, paysage standard, autoradio Android, tablette).
const _androidSizes = <String, Size>{
  'small_portrait_320x568': Size(320, 568),
  'compact_portrait_360x640': Size(360, 640),
  'standard_portrait_390x844': Size(390, 844),
  'poco_portrait_400x869': Size(400, 869),
  'short_landscape_640x320': Size(640, 320),
  'standard_landscape_800x360': Size(800, 360),
  'headunit_1024x600': Size(1024, 600),
  'ultrawide_car_1280x480': Size(1280, 480),
  'tablet_1024x768': Size(1024, 768),
};

Future<DashboardController> _makeController({
  VehicleProfile? profile,
  bool populated = false,
  String? statusOverride,
  String connState = 'idle',
}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  await s.load();
  s.profileSelected = true;
  if (profile != null) {
    s.profileId = profile.id;
    s.tankCapacity = profile.tankCapacity;
    s.fuelRemaining = profile.tankCapacity * 0.71;
  } else {
    s.fuelRemaining = 39.0;
  }
  s.tripKm = 124.8;
  s.tripFuel = 8.95;
  s.tripSeconds = 5420;

  final c = DashboardController(s);
  c.connState = connState;
  if (statusOverride != null) c.status = statusOverride;

  if (populated) {
    c.rpm = 2450;
    c.speed = 92;
    c.lph = 6.8;
    c.l100Inst = 7.4;
    c.ecuId = '06A906019AM 1.6l R4/2V SIMOS HS2554';
    c.data.set(EngineRole.rpm, 2450);
    c.data.set(EngineRole.coolant, 90);
    c.data.set(EngineRole.intakeAir, 28);
    c.data.set(EngineRole.battery, 14.15);
    c.data.set(EngineRole.injection, 4.34);
    c.data.set(EngineRole.lambda, -2.3);
    c.data.set(EngineRole.maf, 14.2);
    c.data.set(EngineRole.throttle, 18.5);
    if (profile?.isDiesel == true) {
      c.data.set(EngineRole.fuelMg, 18.4);
      c.data.set(EngineRole.map, 1890);
      c.data.set(EngineRole.maf, 620);
    } else if (profile?.hasTurbo == true) {
      c.data.set(EngineRole.map, 1780);
    }

    c.faults = [
      FaultCode(522, 0x80),
      FaultCode(1165, 0x20),
      FaultCode(17965, 0x00),
    ];
    c.serviceMessage = 'Calibrage boîtier papillon en cours (5/10 s)…';
    c.throttleProgress = 0.5;
    c.throttleValues = [
      const VagValue(0x01, 10, 20, 4.12, 'V'),
      const VagValue(0x01, 10, 20, 0.88, 'V'),
      const VagValue(0x01, 10, 20, null, '', 'ADP RUN'),
      const VagValue(0x01, 10, 20, 14.2, 'V'),
    ];
    c.groups[1] = [
      const VagValue(0x01, 28, 0, 896, 'tr/min'),
      const VagValue(0x05, 184, 0, 90, '°C'),
      const VagValue(0x01, 128, 0, -1.6, '%'),
      const VagValue(0x01, 0, 0, null, '', '00000010'),
    ];
    c.groupOk[1] = true;
    c.groupF4Raw[1] = [28, 184, 126, 2];
    c.mapping = {
      EngineRole.rpm: '1:0',
      EngineRole.coolant: '1:1',
      EngineRole.lambda: '1:2',
    };
    c.logs.addAll([
      '14:40:01  Init 5-baud 0x01 OK (9600 bauds)',
      '14:40:02  ECU: 06A906019AM 1.6l R4/2V SIMOS HS2554',
    ]);
  }
  return c;
}

Future<void> _pumpWithGuard(
  WidgetTester tester,
  Widget widget,
  Size size, {
  double textScale = 1.0,
  String? label,
}) async {
  final errors = <FlutterErrorDetails>[];
  final prevOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  addTearDown(() {
    FlutterError.onError = prevOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 1.0,
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 24, bottom: 16), // simule encoche + barre gestes Android
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Retro.theme(),
        home: widget,
      ),
    ),
  );
  await tester.pumpAndSettle();

  FlutterError.onError = prevOnError;

  final overflowOrLayoutErrors = errors
      .map((e) => e.exceptionAsString())
      .where((m) => m.contains('overflowed') || m.contains('RenderFlex') || m.contains('hasSize'))
      .toList();
  expect(
    overflowOrLayoutErrors,
    isEmpty,
    reason: 'Erreurs de layout/overflow sur $label ($size, scale=$textScale): $overflowOrLayoutErrors',
  );
  expect(errors, isEmpty, reason: 'Erreurs Flutter sur $label ($size, scale=$textScale): $errors');
}

void main() {
  testWidgets('DashboardScreen : zéro overflow sur toutes les tailles Android (portrait, paysage, autoradio, texte agrandi)',
      (tester) async {
    final longErrCtrl = await _makeController(
      populated: true,
      connState: 'error',
      statusOverride: 'ERREUR : PERMISSION USB REFUSÉE PAR ANDROID',
    );
    final dieselCtrl = await _makeController(
      profile: VehicleProfile.byId('vw_golf4_tdi'),
      populated: true,
      connState: 'connected',
      statusOverride: 'CONNECTÉ MOTEUR',
    );
    final turboCtrl = await _makeController(
      profile: VehicleProfile.byId('audi_a3_8l_18t'),
      populated: true,
      connState: 'sim',
      statusOverride: 'SIMULATION',
    );

    for (final entry in _androidSizes.entries) {
      await _pumpWithGuard(
        tester,
        DashboardScreen(c: longErrCtrl),
        entry.value,
        textScale: 1.0,
        label: 'Dashboard(AKL+LongErr)@${entry.key}',
      );
      await _pumpWithGuard(
        tester,
        DashboardScreen(c: dieselCtrl),
        entry.value,
        textScale: 1.25,
        label: 'Dashboard(TDI+1.25x)@${entry.key}',
      );
      await _pumpWithGuard(
        tester,
        DashboardScreen(c: turboCtrl),
        entry.value,
        textScale: 1.35,
        label: 'Dashboard(1.8T+1.35x)@${entry.key}',
      );
    }
  });

  testWidgets('ProfilePickerScreen : zéro overflow (1er lancement et mode réglages) sur toutes les tailles',
      (tester) async {
    final c = await _makeController();
    for (final entry in _androidSizes.entries) {
      await _pumpWithGuard(
        tester,
        ProfilePickerScreen(settings: c.s, isFirstLaunch: true, onSelected: (_) {}),
        entry.value,
        textScale: 1.25,
        label: 'ProfilePicker(firstLaunch)@${entry.key}',
      );
      await _pumpWithGuard(
        tester,
        ProfilePickerScreen(settings: c.s, isFirstLaunch: false, onSelected: (_) {}),
        entry.value,
        textScale: 1.35,
        label: 'ProfilePicker(settings)@${entry.key}',
      );
    }
  });

  testWidgets('DiagScreen & SettingsScreen : zéro overflow sur toutes les tailles Android', (tester) async {
    final c = await _makeController(populated: true, connState: 'connected', statusOverride: 'CONNECTÉ');
    final updater = UpdateService()
      ..currentVersion = '1.0.1'
      ..availableUpdate = const AppReleaseInfo(
        tag: 'v1.1.0',
        version: '1.1.0',
        title: 'OldBoard v1.1.0',
        notes: '- Mises à jour automatiques via GitHub\n- Nouvelles captures README',
        htmlUrl: 'https://github.com/supermedmed-hash/OldBoard/releases/tag/v1.1.0',
        apkUrl: 'https://github.com/supermedmed-hash/OldBoard/releases/download/v1.1.0/OldBoard-release.apk',
        apkSizeBytes: 48444211,
      );
    for (final entry in _androidSizes.entries) {
      await _pumpWithGuard(
        tester,
        DiagScreen(c: c),
        entry.value,
        textScale: 1.25,
        label: 'DiagScreen@${entry.key}',
      );
      await _pumpWithGuard(
        tester,
        SettingsScreen(c: c, updater: updater),
        entry.value,
        textScale: 1.25,
        label: 'SettingsScreen@${entry.key}',
      );
    }
  });

  test('UpdateService.isNewerVersion compare correctement les tags semver', () {
    expect(UpdateService.isNewerVersion('v1.1.0', '1.0.1'), isTrue);
    expect(UpdateService.isNewerVersion('v1.0.2', '1.0.1'), isTrue);
    expect(UpdateService.isNewerVersion('v2.0.0', '1.9.9'), isTrue);
    expect(UpdateService.isNewerVersion('v1.1.0', '1.1.0'), isFalse);
    expect(UpdateService.isNewerVersion('v1.0.0', '1.1.0'), isFalse);
    expect(UpdateService.isNewerVersion('1.1.0+3', '1.1.0'), isFalse);
  });

  testWidgets('showUpdateDialog : zéro overflow en portrait compact et paysage bas', (tester) async {
    final c = await _makeController();
    final updater = UpdateService()..currentVersion = '1.0.1';
    const release = AppReleaseInfo(
      tag: 'v1.1.0',
      version: '1.1.0',
      title: 'OldBoard v1.1.0',
      notes: '## Nouveautés\n- Mises à jour auto\n- Compatibilité tous Android\n- Optimisations batterie',
      htmlUrl: 'https://github.com/supermedmed-hash/OldBoard/releases/tag/v1.1.0',
      apkUrl: 'https://example.com/app.apk',
      apkSizeBytes: 48000000,
    );

    for (final size in const [Size(320, 568), Size(640, 320)]) {
      final errors = <FlutterErrorDetails>[];
      final prev = FlutterError.onError;
      FlutterError.onError = errors.add;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: Retro.theme(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showUpdateDialog(ctx, updater: updater, settings: c.s, release: release),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      FlutterError.onError = prev;
      expect(errors, isEmpty, reason: 'UpdateDialog overflow sur $size: $errors');
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
    }
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('OldBoardApp clamp protège même à police système extrême (2.0x) sur 320x568', (tester) async {
    final c = await _makeController(populated: true, connState: 'connected', statusOverride: 'CONNECTÉ MOTEUR');
    final errors = <FlutterErrorDetails>[];
    final prev = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() {
      FlutterError.onError = prev;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2.0),
        ),
        child: OldBoardApp(c: c),
      ),
    );
    await tester.pumpAndSettle();
    FlutterError.onError = prev;

    expect(errors, isEmpty, reason: 'OldBoardApp a échoué à fontScale=2.0: $errors');
  });
}
