import 'package:flutter/material.dart';

import '../services/dashboard_controller.dart';
import '../services/update_service.dart';
import 'dashboard_editor_screen.dart';
import 'profile_picker_screen.dart';
import 'theme.dart';
import 'update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.c, this.updater});
  final DashboardController c;
  final UpdateService? updater;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Widget _num(String label, String help, double value, void Function(double) onSet, {int digits = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15, color: Retro.white)),
                const SizedBox(height: 2),
                Text(help, style: const TextStyle(color: Retro.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: TextFormField(
              key: ValueKey('$label$value'),
              initialValue: value.toStringAsFixed(digits),
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Retro.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Retro.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Retro.border),
                ),
              ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.c.s;
    final prof = s.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        top: false,
        child: ListView(
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
          ListTile(
            leading: Icon(Icons.dashboard_customize_rounded, color: prof.accent, size: 28),
            title: Text('Personnaliser le tableau de bord', style: Retro.title(13.5)),
            subtitle: const Text(
              'Vitesse, RPM, Turbo, Charge, Températures… choisir chaque case ou préréglage',
              style: TextStyle(color: Retro.grey, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Retro.silver),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DashboardEditorScreen(settings: s)),
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
          const _Section('Mises à jour automatiques'),
          SwitchListTile(
            title: const Text('Vérifier les mises à jour au lancement'),
            subtitle: const Text('Vérifie silencieusement GitHub Releases lorsqu\'une connexion Internet est disponible'),
            value: s.autoCheckUpdates,
            onChanged: (v) => setState(() {
              s.autoCheckUpdates = v;
              s.changed();
            }),
          ),
          if (widget.updater != null)
            ListenableBuilder(
              listenable: widget.updater!,
              builder: (context, _) {
                final u = widget.updater!;
                final rel = u.availableUpdate;
                final statusText = u.errorMessage ??
                    u.lastMessage ??
                    'Version installée : v${u.currentVersion}';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          color: u.errorMessage != null
                              ? Retro.red
                              : (rel != null ? prof.accent : Retro.silver),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: u.checking || u.downloading
                                ? null
                                : () async {
                                    final found = await u.checkForUpdate(silent: false);
                                    if (found != null && context.mounted) {
                                      showUpdateDialog(
                                        context,
                                        updater: u,
                                        settings: s,
                                        release: found,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(u.checking ? 'Vérification…' : 'Vérifier maintenant'),
                          ),
                          if (rel != null)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: prof.accent, foregroundColor: Colors.white),
                              onPressed: u.downloading
                                  ? null
                                  : () => showUpdateDialog(
                                        context,
                                        updater: u,
                                        settings: s,
                                        release: rel,
                                      ),
                              icon: const Icon(Icons.system_update_rounded, size: 18),
                              label: Text('Installer ${rel.tag}'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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
              'OldBoard lit les capteurs KWP1281 en direct (sans GPS pour économiser la batterie). '
              'Les fonctions atelier (RAZ défauts, calibrage papillon, Canal 00) demandent toujours une confirmation.',
              style: TextStyle(color: Retro.grey, fontSize: 12),
            ),
          ),
        ],
      ),
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
