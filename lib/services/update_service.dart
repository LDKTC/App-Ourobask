import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../app_info.dart';

/// เวอร์ชันแบบ semantic version ที่เอามาเทียบกันได้ เช่น `v1.2.3+4`
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease = '',
    this.build = 0,
  });

  final int major;
  final int minor;
  final int patch;

  /// ส่วนหลังขีด เช่น `beta.1` — ถือว่าเก่ากว่าเวอร์ชันเดียวกันที่ไม่มีส่วนนี้
  final String preRelease;

  /// เลข build หลังเครื่องหมาย `+` (ใช้ตัดสินเมื่อเลขเวอร์ชันเท่ากันทุกส่วน)
  final int build;

  /// อ่านได้ทั้ง `1.2.3`, `v1.2.3`, `1.2.3+4` และ `1.2.3-beta.1`
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    String text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('v') || text.startsWith('V')) text = text.substring(1);

    int build = 0;
    final int plus = text.indexOf('+');
    if (plus >= 0) {
      build = int.tryParse(text.substring(plus + 1).trim()) ?? 0;
      text = text.substring(0, plus);
    }

    String preRelease = '';
    final int dash = text.indexOf('-');
    if (dash >= 0) {
      preRelease = text.substring(dash + 1).trim();
      text = text.substring(0, dash);
    }

    final List<String> parts = text.split('.');
    final int? major = int.tryParse(parts.isNotEmpty ? parts[0].trim() : '');
    if (major == null) return null;
    final int minor = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    final int patch = parts.length > 2 ? int.tryParse(parts[2].trim()) ?? 0 : 0;
    return AppVersion(major, minor, patch, preRelease: preRelease, build: build);
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (preRelease != other.preRelease) {
      // ไม่มี pre-release = เวอร์ชันจริง ถือว่าใหม่กว่ารุ่นทดสอบของเลขเดียวกัน
      if (preRelease.isEmpty) return 1;
      if (other.preRelease.isEmpty) return -1;
      return preRelease.compareTo(other.preRelease);
    }
    return build.compareTo(other.build);
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease, build);

  @override
  String toString() {
    final String base = '$major.$minor.$patch';
    return preRelease.isEmpty ? base : '$base-$preRelease';
  }
}

/// ไฟล์ที่แนบมากับรีลีสหนึ่งอัน
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size});

  final String name;
  final String url;
  final int size;

  bool get isApk => name.toLowerCase().endsWith('.apk');

  static ReleaseAsset? fromJson(Map<String, Object?> json) {
    final String? name = json['name'] as String?;
    final String? url = json['browser_download_url'] as String?;
    if (name == null || url == null) return null;
    return ReleaseAsset(name: name, url: url, size: (json['size'] as num?)?.toInt() ?? 0);
  }
}

/// ข้อมูลรีลีสล่าสุดที่อ่านมาจาก GitHub
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.title,
    required this.notes,
    required this.htmlUrl,
    required this.assets,
    this.publishedAt,
    this.preRelease = false,
  });

  final String tag;
  final AppVersion version;
  final String title;
  final String notes;
  final String htmlUrl;
  final List<ReleaseAsset> assets;
  final DateTime? publishedAt;
  final bool preRelease;

  List<ReleaseAsset> get apks => assets.where((ReleaseAsset a) => a.isApk).toList();

  /// เลือกไฟล์ APK ที่เหมาะกับเครื่อง — ถ้ามีไฟล์แยกตาม ABI จะได้ไฟล์เล็กกว่า
  ReleaseAsset? apkFor(List<String> abis) {
    final List<ReleaseAsset> candidates = apks;
    if (candidates.isEmpty) return null;
    for (final String abi in abis) {
      for (final ReleaseAsset asset in candidates) {
        if (asset.name.toLowerCase().contains(abi.toLowerCase())) return asset;
      }
    }
    // ไม่มีไฟล์ของ ABI นี้ → ใช้ไฟล์รวมทุกสถาปัตยกรรม (ชื่อไม่มี abi ต่อท้าย)
    for (final ReleaseAsset asset in candidates) {
      final String lower = asset.name.toLowerCase();
      final bool perAbi =
          lower.contains('arm64') || lower.contains('armeabi') || lower.contains('x86');
      if (!perAbi) return asset;
    }
    return candidates.first;
  }

  static ReleaseInfo? fromJson(Map<String, Object?> json) {
    final String? tag = json['tag_name'] as String?;
    final AppVersion? version = AppVersion.tryParse(tag);
    if (tag == null || version == null) return null;
    final List<Object?> rawAssets = (json['assets'] as List<Object?>?) ?? <Object?>[];
    final List<ReleaseAsset> assets = <ReleaseAsset>[];
    for (final Object? item in rawAssets) {
      if (item is! Map<String, Object?>) continue;
      final ReleaseAsset? asset = ReleaseAsset.fromJson(item);
      if (asset != null) assets.add(asset);
    }
    final String title = (json['name'] as String? ?? '').trim();
    return ReleaseInfo(
      tag: tag,
      version: version,
      title: title.isEmpty ? tag : title,
      notes: (json['body'] as String? ?? '').trim(),
      htmlUrl: json['html_url'] as String? ?? AppInfo.releasesUrl,
      assets: assets,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      preRelease: json['prerelease'] as bool? ?? false,
    );
  }
}

enum UpdateStatus {
  /// ใช้เวอร์ชันล่าสุดอยู่แล้ว
  upToDate,

  /// มีเวอร์ชันใหม่ให้อัปเดต
  available,

  /// ยังไม่เคยมีรีลีสบน GitHub
  noRelease,
}

/// ผลของการตรวจสอบอัปเดตหนึ่งครั้ง
class UpdateCheck {
  const UpdateCheck({required this.status, required this.currentVersion, this.release});

  final UpdateStatus status;
  final AppVersion currentVersion;
  final ReleaseInfo? release;

  bool get hasUpdate => status == UpdateStatus.available && release != null;
}

/// ข้อผิดพลาดที่อธิบายเป็นภาษาคนได้ (ใช้แสดงบน UI ตรง ๆ)
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// ตรวจสอบรีลีสใหม่จาก GitHub แล้วดาวน์โหลด/ติดตั้ง APK ให้ในแอป
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('ourobask/installer');

  static const Duration _timeout = Duration(seconds: 25);

  String? _cachedVersion;
  List<String>? _cachedAbis;

  /// ติดตั้งทับในแอปได้เฉพาะ Android เท่านั้น
  bool get canInstallInApp => !kIsWeb && Platform.isAndroid;

  /// เวอร์ชันที่ติดตั้งอยู่จริง (อ่านจากระบบ ถ้าไม่ได้ใช้ค่าใน [AppInfo])
  Future<String> currentVersionName() async {
    final String? cached = _cachedVersion;
    if (cached != null) return cached;
    String result = AppInfo.version;
    if (canInstallInApp) {
      try {
        final String? name = await channel.invokeMethod<String>('versionName');
        if (name != null && name.trim().isNotEmpty) result = name.trim();
      } on PlatformException {
        // ใช้ค่าที่คอมไพล์มากับแอปแทน
      } on MissingPluginException {
        // เครื่องที่ยังไม่มี channel นี้ (เช่น รันบนเทสต์)
      }
    }
    _cachedVersion = result;
    return result;
  }

  Future<AppVersion> currentVersion() async =>
      AppVersion.tryParse(await currentVersionName()) ??
      AppVersion.tryParse(AppInfo.version)!;

  /// สถาปัตยกรรมที่เครื่องรองรับ เรียงจากที่เหมาะที่สุด
  Future<List<String>> deviceAbis() async {
    final List<String>? cached = _cachedAbis;
    if (cached != null) return cached;
    List<String> result = const <String>[];
    if (canInstallInApp) {
      try {
        final List<Object?>? abis = await channel.invokeMethod<List<Object?>>('abis');
        result = (abis ?? <Object?>[]).whereType<String>().toList();
      } on PlatformException {
        result = const <String>[];
      } on MissingPluginException {
        result = const <String>[];
      }
    }
    _cachedAbis = result;
    return result;
  }

  /// อ่านรีลีสล่าสุดจาก GitHub
  Future<ReleaseInfo?> fetchLatestRelease() async {
    final Object? json = await _getJson(Uri.parse(AppInfo.latestReleaseApi));
    if (json is! Map<String, Object?>) return null;
    return ReleaseInfo.fromJson(json);
  }

  /// ตรวจสอบว่ามีเวอร์ชันใหม่กว่าที่ติดตั้งอยู่หรือไม่
  Future<UpdateCheck> checkForUpdate() async {
    final AppVersion current = await currentVersion();
    final ReleaseInfo? release = await fetchLatestRelease();
    if (release == null) {
      return UpdateCheck(status: UpdateStatus.noRelease, currentVersion: current);
    }
    return UpdateCheck(
      status: release.version.isNewerThan(current)
          ? UpdateStatus.available
          : UpdateStatus.upToDate,
      currentVersion: current,
      release: release,
    );
  }

  /// โฟลเดอร์เก็บไฟล์ที่ดาวน์โหลดมา (ต้องตรงกับ `files-path` ใน file_paths.xml)
  Future<Directory> _downloadDir() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory('${base.path}/updates');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// ดาวน์โหลด APK พร้อมรายงานความคืบหน้า (received, total) — total = -1 ถ้าไม่รู้
  Future<File> downloadApk(
    ReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
  }) async {
    final Directory dir = await _downloadDir();
    // ลบไฟล์ค้างของรอบก่อน ๆ เพื่อไม่ให้กินพื้นที่เครื่อง
    for (final FileSystemEntity old in dir.listSync()) {
      if (old is File && old.path != '${dir.path}/${asset.name}') {
        try {
          old.deleteSync();
        } on FileSystemException {
          // ลบไม่ได้ก็ปล่อยไว้
        }
      }
    }

    final File file = File('${dir.path}/${asset.name}');
    final File temp = File('${file.path}.part');
    final HttpClient client = _client();
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(asset.url));
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      request.headers.set(HttpHeaders.userAgentHeader, AppInfo.userAgent);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('ดาวน์โหลดไม่สำเร็จ (HTTP ${response.statusCode})');
      }
      final int total = response.contentLength > 0
          ? response.contentLength
          : (asset.size > 0 ? asset.size : -1);
      final IOSink sink = temp.openWrite();
      int received = 0;
      try {
        await for (final List<int> chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (file.existsSync()) file.deleteSync();
      await temp.rename(file.path);
      return file;
    } on SocketException {
      throw const UpdateException('เชื่อมต่ออินเทอร์เน็ตไม่ได้');
    } finally {
      client.close(force: true);
      if (temp.existsSync()) {
        try {
          temp.deleteSync();
        } on FileSystemException {
          // ไฟล์ถูก rename ไปแล้วในกรณีปกติ
        }
      }
    }
  }

  /// Android 8 ขึ้นไปต้องได้รับสิทธิ์ "ติดตั้งแอปที่ไม่รู้จัก" ก่อน
  Future<bool> canRequestInstalls() async {
    if (!canInstallInApp) return false;
    try {
      return await channel.invokeMethod<bool>('canRequestInstalls') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openInstallPermissionSettings() async {
    if (!canInstallInApp) return;
    try {
      await channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException catch (error) {
      throw UpdateException('เปิดหน้าตั้งค่าไม่ได้: ${error.message}');
    }
  }

  /// ส่งไฟล์ให้ระบบติดตั้ง (ผู้ใช้ต้องกดยืนยันในหน้าจอของ Android เอง)
  Future<void> installApk(File file) async {
    if (!canInstallInApp) {
      throw const UpdateException('ติดตั้งในแอปได้เฉพาะบน Android');
    }
    try {
      await channel.invokeMethod<void>('install', <String, Object?>{'path': file.path});
    } on PlatformException catch (error) {
      throw UpdateException('เริ่มการติดตั้งไม่ได้: ${error.message}');
    } on MissingPluginException {
      throw const UpdateException('เครื่องนี้ยังไม่รองรับการติดตั้งในแอป');
    }
  }

  HttpClient _client() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = AppInfo.userAgent;

  Future<Object?> _getJson(Uri url) async {
    final HttpClient client = _client();
    try {
      final HttpClientRequest request = await client.getUrl(url);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');
      final HttpClientResponse response = await request.close().timeout(_timeout);
      final String body = await response
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      switch (response.statusCode) {
        case HttpStatus.ok:
          return jsonDecode(body);
        case HttpStatus.notFound:
          // repo ยังไม่มีรีลีสสักอัน
          return null;
        case HttpStatus.forbidden:
          throw const UpdateException(
            'GitHub จำกัดจำนวนครั้งการเรียกชั่วคราว ลองใหม่อีกครั้งภายหลัง',
          );
        default:
          throw UpdateException('ตรวจสอบอัปเดตไม่สำเร็จ (HTTP ${response.statusCode})');
      }
    } on SocketException {
      throw const UpdateException('เชื่อมต่ออินเทอร์เน็ตไม่ได้');
    } on TimeoutException {
      throw const UpdateException('เชื่อมต่อ GitHub ไม่ทันเวลา ลองใหม่อีกครั้ง');
    } on FormatException {
      throw const UpdateException('ข้อมูลรีลีสจาก GitHub อ่านไม่ได้');
    } finally {
      client.close(force: true);
    }
  }
}
