import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ourobask/app_info.dart';
import 'package:ourobask/services/update_service.dart';

void main() {
  group('เทียบเวอร์ชัน', () {
    test('อ่านรูปแบบต่าง ๆ ของแท็กได้', () {
      expect(AppVersion.tryParse('v1.2.3').toString(), '1.2.3');
      expect(AppVersion.tryParse('1.2.3').toString(), '1.2.3');
      expect(AppVersion.tryParse('1.2').toString(), '1.2.0');
      expect(AppVersion.tryParse('v2').toString(), '2.0.0');
      expect(AppVersion.tryParse('1.2.3+7')?.build, 7);
      expect(AppVersion.tryParse('1.2.3-beta.1')?.preRelease, 'beta.1');
    });

    test('ค่าที่อ่านไม่ได้คืน null', () {
      expect(AppVersion.tryParse(null), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('release'), isNull);
    });

    test('เทียบลำดับเวอร์ชันถูกต้อง', () {
      bool newer(String a, String b) =>
          AppVersion.tryParse(a)!.isNewerThan(AppVersion.tryParse(b)!);

      expect(newer('1.0.1', '1.0.0'), isTrue);
      expect(newer('1.1.0', '1.0.9'), isTrue);
      expect(newer('2.0.0', '1.9.9'), isTrue);
      expect(newer('1.0.0', '1.0.0'), isFalse);
      expect(newer('1.0.0', '1.0.1'), isFalse);
      expect(newer('1.10.0', '1.9.0'), isTrue);
    });

    test('รุ่นทดสอบถือว่าเก่ากว่ารุ่นจริงของเลขเดียวกัน', () {
      final AppVersion beta = AppVersion.tryParse('1.2.0-beta.1')!;
      final AppVersion stable = AppVersion.tryParse('1.2.0')!;
      expect(stable.isNewerThan(beta), isTrue);
      expect(beta.isNewerThan(stable), isFalse);
    });

    test('เลข build ใช้ตัดสินเมื่อเลขเวอร์ชันเท่ากัน', () {
      final AppVersion older = AppVersion.tryParse('1.0.0+1')!;
      final AppVersion newer = AppVersion.tryParse('1.0.0+2')!;
      expect(newer.isNewerThan(older), isTrue);
    });
  });

  group('ข้อมูลรีลีสจาก GitHub', () {
    Map<String, Object?> releaseJson({
      String tag = 'v1.2.0',
      List<String> assets = const <String>['ourobask-v1.2.0.apk'],
    }) => <String, Object?>{
      'tag_name': tag,
      'name': 'Ourobask $tag',
      'body': 'รายละเอียดของรีลีส',
      'html_url': 'https://github.com/${AppInfo.repoSlug}/releases/tag/$tag',
      'published_at': '2026-04-01T10:00:00Z',
      'prerelease': false,
      'assets': <Map<String, Object?>>[
        for (final String name in assets)
          <String, Object?>{
            'name': name,
            'browser_download_url': 'https://example.invalid/$name',
            'size': 1024,
          },
      ],
    };

    test('อ่านข้อมูลหลักของรีลีสได้', () {
      final ReleaseInfo release = ReleaseInfo.fromJson(releaseJson())!;
      expect(release.tag, 'v1.2.0');
      expect(release.version.toString(), '1.2.0');
      expect(release.title, 'Ourobask v1.2.0');
      expect(release.notes, 'รายละเอียดของรีลีส');
      expect(release.publishedAt, isNotNull);
      expect(release.apks, hasLength(1));
    });

    test('รีลีสที่แท็กอ่านไม่ได้ถูกข้าม', () {
      expect(ReleaseInfo.fromJson(releaseJson(tag: 'nightly')), isNull);
      expect(ReleaseInfo.fromJson(<String, Object?>{}), isNull);
    });

    test('เลือกไฟล์ตามสถาปัตยกรรมของเครื่องก่อน', () {
      final ReleaseInfo release = ReleaseInfo.fromJson(
        releaseJson(
          assets: <String>[
            'ourobask-v1.2.0.apk',
            'ourobask-v1.2.0-arm64-v8a.apk',
            'ourobask-v1.2.0-armeabi-v7a.apk',
          ],
        ),
      )!;
      expect(
        release.apkFor(<String>['arm64-v8a', 'armeabi-v7a'])?.name,
        'ourobask-v1.2.0-arm64-v8a.apk',
      );
      expect(
        release.apkFor(<String>['armeabi-v7a'])?.name,
        'ourobask-v1.2.0-armeabi-v7a.apk',
      );
    });

    test('ไม่มีไฟล์ของสถาปัตยกรรมนั้นก็ใช้ไฟล์รวม', () {
      final ReleaseInfo release = ReleaseInfo.fromJson(
        releaseJson(
          assets: <String>['ourobask-v1.2.0.apk', 'ourobask-v1.2.0-x86_64.apk'],
        ),
      )!;
      expect(release.apkFor(<String>['riscv64'])?.name, 'ourobask-v1.2.0.apk');
    });

    test('รีลีสที่ไม่มี APK เลยคืน null', () {
      final ReleaseInfo release = ReleaseInfo.fromJson(
        releaseJson(assets: <String>['ourobask-source.zip']),
      )!;
      expect(release.apks, isEmpty);
      expect(release.apkFor(<String>['arm64-v8a']), isNull);
    });

    test('ไฟล์แนบที่ข้อมูลไม่ครบถูกข้ามไป', () {
      final Map<String, Object?> json = releaseJson();
      (json['assets']! as List<Map<String, Object?>>).add(<String, Object?>{
        'name': 'broken.apk',
      });
      final ReleaseInfo release = ReleaseInfo.fromJson(json)!;
      expect(release.assets, hasLength(1));
    });
  });

  group('ข้อมูลระบุตัวแอป', () {
    test('เวอร์ชันใน AppInfo ตรงกับ pubspec.yaml', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final RegExp pattern = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);
      final RegExpMatch? match = pattern.firstMatch(pubspec);
      expect(match, isNotNull, reason: 'ไม่พบบรรทัด version ใน pubspec.yaml');
      final List<String> parts = match!.group(1)!.split('+');
      expect(parts.first, AppInfo.version);
      expect(int.parse(parts.last), AppInfo.buildNumber);
    });

    test('ที่อยู่ของ repo ประกอบเป็น URL ที่ถูกต้อง', () {
      expect(AppInfo.repoSlug, '${AppInfo.repoOwner}/${AppInfo.repoName}');
      expect(
        AppInfo.latestReleaseApi,
        'https://api.github.com/repos/${AppInfo.repoSlug}/releases/latest',
      );
      expect(Uri.tryParse(AppInfo.releasesUrl)?.host, 'github.com');
    });
  });
}
