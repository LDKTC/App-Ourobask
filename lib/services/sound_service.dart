import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// เสียงที่ผู้ใช้เลือกไว้สำหรับการปลุก
class PickedSound {
  const PickedSound(this.uri, this.name);

  final String uri;
  final String name;
}

/// เลือก/ลองฟังเสียงปลุกจากเครื่องของผู้ใช้
///
/// รองรับสองทาง:
///  1. เสียงของระบบ (ตัวเลือกเสียงมาตรฐานของ Android)
///  2. ไฟล์เสียงในเครื่อง — คัดลอกเข้าโฟลเดอร์แอปแล้วแปลงเป็น content:// ให้ระบบอ่านได้
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const MethodChannel _channel = MethodChannel('ourobask/sound');

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<PickedSound?> pickSystemSound({String? currentUri}) async {
    if (!isAndroid) return null;
    final Map<Object?, Object?>? result = await _channel
        .invokeMethod<Map<Object?, Object?>>('pickRingtone', <String, Object?>{
          'currentUri': currentUri,
        });
    if (result == null) return null;
    return PickedSound(
      result['uri']! as String,
      (result['name'] as String?) ?? 'เสียงที่เลือก',
    );
  }

  Future<PickedSound?> pickAudioFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'เลือกไฟล์เสียงปลุก',
      type: FileType.audio,
    );
    final String? path = picked?.files.single.path;
    if (path == null) return null;

    final String name = p.basename(path);
    final String storedPath = await _copyIntoAppSounds(path, name);
    if (!isAndroid) return PickedSound(storedPath, name);

    final String? uri = await _channel.invokeMethod<String>(
      'contentUriFor',
      <String, Object?>{'path': storedPath},
    );
    return uri == null ? null : PickedSound(uri, name);
  }

  Future<String> _copyIntoAppSounds(String sourcePath, String name) async {
    final Directory base =
        (isAndroid ? await getExternalStorageDirectory() : null) ??
        await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(base.path, 'sounds'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final File target = File(p.join(dir.path, name));
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Future<String?> titleOf(String uri) async {
    if (!isAndroid) return null;
    return _channel.invokeMethod<String>('titleOf', <String, Object?>{'uri': uri});
  }

  /// ลองฟังเสียงด้วยระดับเสียงแบบเดียวกับตอนปลุกจริง
  Future<bool> preview(String uri) async {
    if (!isAndroid) return false;
    return await _channel.invokeMethod<bool>('preview', <String, Object?>{'uri': uri}) ??
        false;
  }

  Future<void> stopPreview() async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('stopPreview');
  }
}
