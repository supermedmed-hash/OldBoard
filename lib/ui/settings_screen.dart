import 'package:flutter/material.dart';

import '../services/dashboard_controller.dart';
import 'profile_picker_screen.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.c});
  final DashboardController c;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Widget _num(String label, String help, double value, void Function(double) onSet, {int digits = 1}) {
    return ListTile(
      title: Text(label),
      subtitle: Text(help, style: const TextStyle(color: Retro.grey, fontSize: 12)),
      trailing: SizedBox(
        width: 110,
        child: TextFormField(
          key: ValueKey('$label$value'),
          initialValue: value.toStringAsFixed(digits),
          textAlign: TextAlign.end,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onFieldSubmitted: (t) {
            final v = double.tryParse(t.replaceAll(',', '.'));
            if (v != null) {
              onSet(v);
              widget.c.s.changed();
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.c.s;
    final prof = s.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          _Section('Profil véhicule & Thème OEM', color: prof.accent),
          ListTile(
            leading: BrandEmblem(brand: prof.brand, accent: prof.accent, size: 30),
            title: Text(prof.name, style: Retro.title(13.5)),
            subtitle: Text(prof.subtitle, style: const TextStyle(color: Retro.grey, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Retro.silver),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfilePickerScreen(
                    settings: s,
                    onSelected: (picked) {
                      s.applyProfile(picked);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          _Section('Paramètres – ${prof.headerShort}', color: prof.accent),
          _num('Réservoir (L)', 'Capacité du réservoir', s.tankCapacity, (v) => s.tankCapacity = v, digits: 0),
          _num('Carburant restant (L)', 'Correction manuelle de la jauge', s.fuelRemaining, (v) => s.fuelRemaining = v),
          _num('Débit injecteur (cc/min)', 'Débit d\'un injecteur à 3 bar', s.injectorFlow, (v) => s.injectorFlow = v,
              digits: 0),
          _num('Temps mort injecteur (ms)', 'Laisser 0 si inconnu', s.injectorDeadTime, (v) => s.injectorDeadTime = v,
              digits: 2),
          _num('Facteur de calibration', 'Ajusté automatiquement à chaque plein complet', s.calibration,
              (v) => s.calibration = v,
              digits: 3),
          const _Section('Options OBD KWP1281'),
          SwitchListTile(
            title: const Text('Lire la jauge au combiné (0x17)'),
            subtitle: const Text('Lit le niveau d\'essence au démarrage, puis bascule sur le moteur (0x01)'),
            value: s.readClusterFuel,
            onChanged: (v) => setState(() {
              s.readClusterFuel = v;
              s.changed();
            }),
          ),
          SwitchListTile(
            title: const Text('Détection auto du véhicule (OBD)'),
            subtitle: const Text('Adapte automatiquement le profil, le thème et les groupes selon la référence du calculateur'),
            value: s.autoDetectVehicle,
            onChanged: (v) => setState(() {
              s.autoDetectVehicle = v;
              s.changed();
            }),
          ),
          SwitchListTile(
            title: const Text('Connexion automatique'),
            subtitle: const Text('Se connecte dès que le câble USB est branché'),
            value: s.autoConnect,
            onChanged: (v) => setState(() {
              s.autoConnect = v;
              s.changed();
            }),
          ),
          const _Section('Mémoires'),
          ListTile(
            title: const Text('Remettre le trajet à zéro'),
            leading: const Icon(Icons.restart_alt),
            onTap: () {
              widget.c.resetTrip();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trajet remis à zéro')));
            },
          ),
          ListTile(
            title: const Text('Réinitialiser la calibration conso'),
            leading: const Icon(Icons.tune),
            onTap: () {
              s.calibration = 1.0;
              s.changed();
              setState(() {});
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'OldBoard est en LECTURE SEULE (et sans GPS pour économiser la batterie) : '
              'il ne peut ni effacer de codes, ni coder, ni reprogrammer le calculateur.',
              style: TextStyle(color: Retro.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.t, {this.color = Retro.red});
  final String t;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12)),
      );
}
