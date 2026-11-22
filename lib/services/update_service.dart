import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Informations sur une release GitHub disponible.
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.tag,
    required this.version,
    required this.title,
    required this.notes,
    required this.htmlUrl,
    this.apkUrl,
    this.apkSizeBytes = 0,
  });

  final String tag;
  final String version;
  final String title;
  final String notes;
  final String htmlUrl;
  final String? apkUrl;
  final int apkSizeBytes;

  String get sizeLabel {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} Mo';
  }
}

/// Service de mise à jour automatique via GitHub Releases (sans dépendance externe).
class UpdateService extends ChangeNotifier {
  static const repoOwner = 'supermedmed-hash';
  static const repoName = 'OldBoard';
  static const fallbackVersion = '1.2.1';
  static const _channel = MethodChannel('oldboard/updater');
  static const _progressChannel = EventChannel('oldboard/updater/progress');

  String currentVersion = fallbackVersion;
  AppReleaseInfo? availableUpdate;
  bool checking = false;
  bool downloading = false;
  double? downloadProgress; // 0.0..1.0 ou null si indéterminé
  String? lastMessage;
  String? errorMessage;

  StreamSubscription? _progressSub;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!supported) return;
    try {
      final v = await _channel.invokeMethod<String>('getAppVersion');
      if (v != null && v.trim().isNotEmpty) {
        currentVersion = v.trim();
      }
    } catch (_) {}

    _progressSub ??= _progressChannel.receiveBroadcastStream().listen(_onNativeProgress);
    notifyListeners();
  }

  void _onNativeProgress(dynamic raw) {
    if (raw is! Map) return;
    final state = raw['state'] as String?;
    switch (state) {
      case 'downloading':
        downloading = true;
        errorMessage = null;
        final p = (raw['progress'] as num?)?.toDouble() ?? -1.0;
        downloadProgress = p >= 0 ? p.clamp(0.0, 1.0) : null;
        lastMessage = downloadProgress != null
            ? 'Téléchargement… ${(downloadProgress! * 100).toStringAsFixed(0)} %'
            : 'Téléchargement de la mise à jour…';
      case 'installing':
        downloading = false;
        downloadProgress = 1.0;
        lastMessage = 'Ouverture de l\'installeur Android…';
      case 'done':
        downloading = false;
        lastMessage = 'Installeur lancé — valide la mise à jour sur Android.';
      case 'error':
        downloading = false;
        downloadProgress = null;
        errorMessage = (raw['msg'] as String?) ?? 'Échec du téléchargement';
    }
    notifyListeners();
  }

  /// Compare deux versions semver (ex: "v1.1.0" vs "1.0.1" => true).
  static bool isNewerVersion(String remoteTag, String localVersion) {
    List<int> parse(String raw) {
      final cleaned = raw.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first.split('-').first;
      return cleaned.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    }

    final r = parse(remoteTag);
    final l = parse(localVersion);
    final len = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  /// Interroge GitHub Releases (`latest`). Retourne l'info si une version plus récente existe.
  Future<AppReleaseInfo?> checkForUpdate({bool silent = false}) async {
    if (checking) return availableUpdate;
    checking = true;
    if (!silent) {
      errorMessage = null;
      lastMessage = 'Recherche de mise à jour…';
    }
    notifyListeners();

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 7);
      final uri = Uri.https('api.github.com', '/repos/$repoOwner/$repoName/releases/latest');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, 'OldBoard-Android/$currentVersion');
      final resp = await req.close().timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        if (!silent) errorMessage = 'Impossible de joindre GitHub (HTTP ${resp.statusCode})';
        return null;
      }

      final body = await resp.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?)?.trim() ?? '';
      if (tag.isEmpty) return null;

      final assets = (json['assets'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      String? apkUrl;
      var apkSize = 0;
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          apkSize = (a['size'] as num?)?.toInt() ?? 0;
          break;
        }
      }

      final info = AppReleaseInfo(
        tag: tag,
        version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
        title: (json['name'] as String?)?.trim().isNotEmpty == true ? (json['name'] as String).trim() : 'OldBoard $tag',
        notes: (json['body'] as String?)?.trim() ?? '',
        htmlUrl: (json['html_url'] as String?) ?? 'https://github.com/$repoOwner/$repoName/releases/latest',
        apkUrl: apkUrl,
        apkSizeBytes: apkSize,
      );

      if (isNewerVersion(tag, currentVersion)) {
        availableUpdate = info;
        lastMessage = 'Nouvelle version disponible : $tag';
        return info;
      } else {
        availableUpdate = null;
        if (!silent) lastMessage = 'OldBoard est à jour (v$currentVersion) ✔';
        return null;
      }
    } catch (_) {
      // Silencieux en voiture / hors-ligne pour ne jamais déranger la conduite.
      if (!silent) errorMessage = 'Pas de connexion Internet pour vérifier les mises à jour.';
      return null;
    } finally {
      client?.close(force: true);
      checking = false;
      notifyListeners();
    }
  }

  /// Télécharge l'APK et lance l'installeur natif Android (ou ouvre GitHub en secours).
  Future<void> downloadAndInstall(AppReleaseInfo info) async {
    if (downloading) return;
    if (!supported || info.apkUrl == null || info.apkUrl!.isEmpty) {
      await openReleasePage(info.htmlUrl);
      return;
    }
    downloading = true;
    downloadProgress = 0.0;
    errorMessage = null;
    lastMessage = 'Démarrage du téléchargement…';
    notifyListeners();
    try {
      await _channel.invokeMethod('downloadAndInstall', {'url': info.apkUrl});
    } catch (e) {
      downloading = false;
      downloadProgress = null;
      errorMessage = 'Impossible de démarrer le téléchargement ($e)';
      notifyListeners();
    }
  }

  Future<void> openReleasePage(String url) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}
