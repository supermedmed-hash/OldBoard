import 'package:flutter/material.dart';

import '../services/settings.dart';
import '../services/update_service.dart';
import 'theme.dart';

/// Fenêtre OEM propre pour présenter et installer une nouvelle version GitHub d'OldBoard.
Future<void> showUpdateDialog(
  BuildContext context, {
  required UpdateService updater,
  required AppSettings settings,
  required AppReleaseInfo release,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => ListenableBuilder(
      listenable: updater,
      builder: (ctx, _) {
        final accent = settings.profile.accent;
        final busy = updater.downloading;
        return AlertDialog(
          backgroundColor: Retro.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: accent.withValues(alpha: 0.7), width: 1.4),
          ),
          title: Row(
            children: [
              Icon(Icons.system_update_rounded, color: accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mise à jour ${release.tag}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Retro.title(15, c: Retro.white),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340, maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Version installée : v${updater.currentVersion}  →  Nouvelle : ${release.tag}'
                    '${release.sizeLabel.isNotEmpty ? ' (${release.sizeLabel})' : ''}',
                    style: const TextStyle(color: Retro.silver, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  if (release.notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Retro.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Retro.borderSubtle),
                      ),
                      child: Text(
                        release.notes,
                        style: const TextStyle(color: Retro.silver, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                  if (busy || updater.downloadProgress != null) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: updater.downloadProgress,
                      backgroundColor: Retro.border,
                      color: accent,
                    ),
                    if (updater.lastMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        updater.lastMessage!,
                        style: const TextStyle(color: Retro.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                  if (updater.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      updater.errorMessage!,
                      style: const TextStyle(color: Retro.red, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (!busy)
              TextButton(
                onPressed: () {
                  settings.ignoredUpdateTag = release.tag;
                  settings.changed();
                  Navigator.pop(ctx);
                },
                child: const Text('Ignorer', style: TextStyle(color: Retro.grey)),
              ),
            if (!busy)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Plus tard'),
              ),
            if (updater.errorMessage != null && !busy)
              OutlinedButton(
                onPressed: () => updater.openReleasePage(release.htmlUrl),
                child: const Text('Ouvrir GitHub'),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
              onPressed: busy ? null : () => updater.downloadAndInstall(release),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(busy ? 'Téléchargement…' : 'Télécharger & installer'),
            ),
          ],
        );
      },
    ),
  );
}
