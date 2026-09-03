/// ข้อมูลระบุตัวแอป — ใช้ตรวจสอบรีลีสใหม่บน GitHub และแสดงในหน้าตั้งค่า
class AppInfo {
  AppInfo._();

  static const String name = 'Ourobask';

  /// ต้องตรงกับ `version` ใน pubspec.yaml (มีเทสต์คอยตรวจให้)
  ///
  /// ใช้เป็นค่าสำรองเมื่ออ่านเวอร์ชันจากระบบปฏิบัติการไม่ได้
  static const String version = '1.2.1';
  static const int buildNumber = 4;

  static const String repoOwner = 'LDKTC';
  static const String repoName = 'App-Ourobask';

  static const String repoSlug = '$repoOwner/$repoName';

  static const String releasesUrl = 'https://github.com/$repoSlug/releases';

  /// GitHub REST API ของรีลีสล่าสุด (ไม่ต้องใช้ token สำหรับ repo สาธารณะ)
  static const String latestReleaseApi =
      'https://api.github.com/repos/$repoSlug/releases/latest';

  static const String userAgent = 'Ourobask-App/$version (+$releasesUrl)';
}
