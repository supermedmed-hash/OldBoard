import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'services/dashboard_controller.dart';
import 'services/settings.dart';
import 'ui/dashboard_screen.dart';
import 'ui/profile_picker_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  try {
    await WakelockPlus.enable(); // l'ecran reste allume pendant la conduite
  } catch (_) {}

  final settings = AppSettings();
  await settings.load();
  final controller = DashboardController(settings);
  await controller.init();
  runApp(OldBoardApp(c: controller));
}

class OldBoardApp extends StatelessWidget {
  const OldBoardApp({super.key, required this.c});
  final DashboardController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c.s,
      builder: (context, _) {
        final prof = c.s.profile;
        return MaterialApp(
          title: 'OldBoard',
          debugShowCheckedModeBanner: false,
          theme: Retro.theme(prof.accent),
          home: c.s.profileSelected
              ? DashboardScreen(c: c)
              : ProfilePickerScreen(
                  settings: c.s,
                  isFirstLaunch: true,
                  onSelected: (picked) => c.s.applyProfile(picked),
                ),
        );
      },
    );
  }
}
