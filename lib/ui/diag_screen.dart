import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/engine_data.dart';
import '../services/dashboard_controller.dart';
import '../services/kline_service.dart';
import '../services/vag_decoder.dart';
import 'theme.dart';

/// Libelles de quelques codes defaut VAG courants (moteur 1.6 Simos).
const _faultNames = <int, String>{
  513: 'Capteur régime moteur (G28)',
  515: 'Capteur de Hall (G40)',
  518: 'Potentiomètre papillon (G69)',
  519: 'Capteur pression collecteur (G71)',
  522: 'Sonde temp. liquide refroidissement (G62)',
  523: 'Sonde temp. air admission (G42)',
  524: 'Capteur cliquetis 1 (G61)',
  525: 'Sonde lambda (G39)',
  532: 'Tension d\'alimentation',
  533: 'Régulation ralenti',
  537: 'Régulation lambda',
  543: 'Régime maxi dépassé',
  557: 'Pressostat de direction assistée (F88)',
  561: 'Adaptation du mélange',
  575: 'Pression collecteur',
  625: 'Signal vitesse',
  668: 'Tension borne 30',
  1087: 'Réglage de base non effectué',
  1165: 'Unité de commande papillon (J338)',
  1247: 'Électrovanne canister (N80)',
  1249: 'Injecteur cylindre 1 (N30)',
  1250: 'Injecteur cylindre 2 (N31)',
  1251: 'Injecteur cylindre 3 (N32)',
  1252: 'Injecteur cylindre 4 (N33)',
  65535: 'Erreur mémoire calculateur',
};

String faultLabel(int code) {
  if (_faultNames.containsKey(code)) return _faultNames[code]!;
  if (code >= 16384 && code < 16384 + 10000) {
    return 'OBD P${(code - 16384).toString().padLeft(4, '0')}';
  }
  return 'Code inconnu';
}

class DiagScreen extends StatefulWidget {
  const DiagScreen({super.key, required this.c});
  final DashboardController c;

  @override
  State<DiagScreen> createState() => _DiagScreenState();
}

class _DiagScreenState extends State<DiagScreen> {
  final _groupCtrl = TextEditingController();

  @override
  void dispose() {
    final c = widget.c;
    if (c.exploreGroup != null) c.explore(null);
    _groupCtrl.dispose();
    super.dispose();
  }

  Future<void> _chooseRole(int g, int i) async {
    final c = widget.c;
    final key = '$g:$i';
    final current = c.mapping.entries.where((e) => e.value == key).map((e) => e.key).toList();
    final res = await showModalBottomSheet<EngineRole?>(
      context: context,
      builder: (ctx) => ListView(
        children: [
          ListTile(title: Text('Groupe $g – champ ${i + 1} : utiliser comme…')),
          for (final r in EngineRole.values)
            ListTile(
              title: Text(r.label),
              trailing: c.mapping[r] == key ? const Icon(Icons.check, color: Retro.red) : null,
              onTap: () => Navigator.pop(ctx, r),
            ),
        ],
      ),
    );
    if (res == null) return;
    if (current.contains(res)) {
      c.assignRole(res, null);
    } else {
      c.assignRole(res, key);
    }
  }

  Future<void> _copyReport() async {
    final report = widget.c.buildDiagReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport complet copié dans le presse-papiers (et sauvegardé) !')),
      );
    }
  }

  Future<void> _confirmAction({
    required String title,
    required String body,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Retro.surface,
        title: Text(title, style: Retro.title(15)),
        content: Text(body, style: const TextStyle(color: Retro.silver, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Retro.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok == true) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final canAct = (c.connState == 'connected' || c.mode == SourceMode.sim) && !c.serviceBusy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic & Atelier Moteur'),
        actions: [
          IconButton(
            tooltip: 'Copier le rapport de diagnostic',
            icon: const Icon(Icons.copy_all),
            onPressed: _copyReport,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _card('Connexion & Export Debug', [
                Text('État : ${c.status}'),
                if (c.ecuId != null) Text('Calculateur : ${c.ecuId}'),
                if (!KLineService.supported)
                  const Text('Le câble USB ne fonctionne que dans l\'application Android.',
                      style: TextStyle(color: Retro.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _copyReport,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copier le rapport complet'),
                    ),
                    OutlinedButton.icon(
                      onPressed: c.clearLogs,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Vider le journal'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Le journal est sauvegardé automatiquement dans la mémoire du téléphone : '
                  'même si tu fermes l\'application dans la voiture, on pourra le relire en rebranchant le POCO au PC.',
                  style: TextStyle(color: Retro.grey, fontSize: 11),
                ),
              ]),
              _card('Bilan mécanique enregistré (Trajet réel)', [
                Text(
                  'Régime max : ${c.s.maxRpm.toStringAsFixed(0)} tr/min  •  '
                  'MAF max : ${c.s.maxMaf.toStringAsFixed(1)} g/s',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Retro.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Papillon min / max : ${c.s.minThrottle >= 0 ? c.s.minThrottle.toStringAsFixed(1) : "--"} ° / ${c.s.maxThrottle.toStringAsFixed(1)} °',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Retro.silver),
                ),
                const SizedBox(height: 4),
                Text(
                  'Eau max : ${c.s.maxCoolant.toStringAsFixed(0)} °C  •  '
                  'Batt min : ${c.s.minBattery > 0 ? c.s.minBattery.toStringAsFixed(2) : "--"} V',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Retro.silver),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lambda min / max : ${c.s.minLambda.toStringAsFixed(1)} % / +${c.s.maxLambda.toStringAsFixed(1)} %',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Retro.silver),
                ),
              ]),
              _card('Codes défaut moteur (Simos 2 – 0x01)', [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: canAct && !c.readingFaults ? c.readFaults : null,
                      icon: const Icon(Icons.search, size: 18),
                      label: Text(c.readingFaults ? 'Lecture…' : 'Lire les codes défaut'),
                    ),
                    OutlinedButton.icon(
                      onPressed: canAct
                          ? () => _confirmAction(
                                title: 'Effacer les codes défaut moteur ?',
                                body: 'Envoie la commande KWP1281 (0x05) au calculateur moteur pour vider la mémoire '
                                    'des défauts et éteindre le voyant.',
                                confirmLabel: 'Effacer les défauts',
                                onConfirm: c.clearFaults,
                              )
                          : null,
                      icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: Retro.red),
                      label: const Text('Effacer les codes (0x05)'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (c.faults != null && c.faults!.isEmpty)
                  const Text('Aucun code défaut mémorisé ✔',
                      style: TextStyle(color: Retro.green, fontWeight: FontWeight.w700)),
                if (c.faults != null)
                  for (final f in c.faults!)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(f.code.toString().padLeft(5, '0'),
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      title: Text(faultLabel(f.code)),
                      subtitle: Text('Type ${f.status & 0x7F}${(f.status & 0x80) != 0 ? ' – sporadique' : ''}'),
                    ),
              ]),
              _card('Atelier Moteur – ${c.s.profile.headerShort} (${c.s.profile.ecuLabel})', [
                if (c.serviceMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Retro.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.serviceBusy ? Retro.blue : Retro.green),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.serviceMessage!,
                          style: const TextStyle(color: Retro.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        if (c.throttleProgress != null) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: c.throttleProgress,
                            backgroundColor: Retro.border,
                            color: Retro.blue,
                          ),
                        ],
                        if (c.throttleValues.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Groupe ${(c.s.profile.throttleBasicGroup ?? 98).toString().padLeft(3, '0')} : ${c.throttleValues.map((v) => v.display).join("  |  ")}',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Retro.silver),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (c.s.profile.throttleBasicGroup != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '1. Recalibrer le boîtier papillon (Groupe ${c.s.profile.throttleBasicGroup!.toString().padLeft(3, '0')})',
                      style: Retro.title(13),
                    ),
                    subtitle: const Text(
                      'Corrige le ralenti instable après débranchement batterie ou nettoyage papillon.\n'
                      '⚠️ À faire MOTEUR COUPÉ, contact mis, sans toucher la pédale d\'accélérateur.',
                      style: TextStyle(color: Retro.grey, fontSize: 11.5),
                    ),
                    trailing: FilledButton(
                      onPressed: canAct
                          ? () => _confirmAction(
                                title:
                                    'Calibrer le boîtier papillon (Groupe ${c.s.profile.throttleBasicGroup!.toString().padLeft(3, '0')}) ?',
                                body: 'Conditions obligatoires avant de lancer :\n\n'
                                    '• Moteur COUPÉ (0 tr/min), contact mis (voyants allumés)\n'
                                    '• Ne PAS toucher la pédale d\'accélérateur\n'
                                    '• Température moteur entre 5 et 95 °C\n\n'
                                    'Le papillon va bouger tout seul en butée min/max pendant ~10 secondes.',
                                confirmLabel: 'Lancer le calibrage',
                                onConfirm: c.startThrottleAlign,
                              )
                          : null,
                      child: const Text('Calibrer'),
                    ),
                  ),
                  const Divider(color: Retro.borderSubtle),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('2. Réinitialiser les auto-adaptations moteur (Canal 00)', style: Retro.title(13)),
                  subtitle: const Text(
                    'Remet à zéro les corrections d\'enrichissement (Lambda) et de ralenti apprises par le calculateur '
                    '(utile après remplacement d\'une sonde, du débitmètre ou réparation d\'une prise d\'air).',
                    style: TextStyle(color: Retro.grey, fontSize: 11.5),
                  ),
                  trailing: OutlinedButton(
                    onPressed: canAct
                        ? () => _confirmAction(
                              title: 'Réinitialiser les auto-adaptations (Canal 00) ?',
                              body: 'Envoie la commande KWP1281 (0x2A Canal 00) au calculateur Simos 2 pour remettre '
                                  'les valeurs d\'apprentissage du mélange et du ralenti aux paramètres d\'usine.',
                              confirmLabel: 'Réinitialiser',
                              onConfirm: c.resetAdaptations,
                            )
                        : null,
                    child: const Text('RAZ Canal 00'),
                  ),
                ),
              ]),
              _card('Explorer un groupe de mesures', [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _groupCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Groupe'),
                      ),
                    ),
                    FilledButton(
                      onPressed: c.connState == 'connected'
                          ? () {
                              final g = int.tryParse(_groupCtrl.text);
                              if (g != null && g >= 0 && g <= 255) c.explore(g);
                            }
                          : null,
                      child: const Text('Lire en continu'),
                    ),
                    if (c.exploreGroup != null)
                      OutlinedButton(onPressed: () => c.explore(null), child: const Text('Stop')),
                  ],
                ),
              ]),
              _card('Blocs de mesures (toucher un champ pour l\'affecter)', [
                if (c.groups.isEmpty && c.groupOk.isEmpty)
                  const Text('Aucune donnée.', style: TextStyle(color: Retro.grey)),
                for (final g in ({...c.groups.keys, ...c.groupOk.keys}.toList()..sort()))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(g.toString().padLeft(3, '0'),
                                  style: const TextStyle(fontFamily: 'monospace', color: Retro.red, fontWeight: FontWeight.w700)),
                            ),
                            if (c.groupOk[g] == false || (c.groups[g]?.isEmpty ?? true))
                              Expanded(
                                child: Text(
                                  c.groupRawInfo[g] ?? 'Échec lecture (ok=false)',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Retro.grey),
                                ),
                              )
                            else
                              for (var i = 0; i < (c.groups[g]?.length ?? 0); i++)
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _chooseRole(g, i),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.groups[g]![i].display,
                                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                                          Text(
                                            c.mapping.entries
                                                .where((e) => e.value == '$g:$i')
                                                .map((e) => e.key.label)
                                                .join(', '),
                                            style: const TextStyle(color: Retro.red, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                        if (c.groupF4Raw[g] != null && c.groupF4Raw[g]!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 48, top: 2),
                            child: Text(
                              formatF4Raw(c.groupF4Raw[g]!),
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Retro.silver),
                            ),
                          ),
                      ],
                    ),
                  ),
              ]),
              _card('Journal (${c.logs.length} lignes)', [
                SizedBox(
                  height: 220,
                  child: ListView(
                    reverse: true,
                    children: [
                      for (final l in c.logs.reversed)
                        Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Retro.grey)),
                    ],
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Card(
        color: Retro.surface,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: Retro.title(12.5, c: Retro.titleWhite)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}
