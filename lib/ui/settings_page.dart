import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import '../data/backup.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import '../state/app_state.dart';
import 'update_page.dart';
import 'widgets/common.dart';

/// ตั้งค่า — ธีม การเตือน เสียงเริ่มต้น และ Export / Import ข้อมูล
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          const SectionHeader(title: 'การแสดงผล', icon: Icons.palette_rounded),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.brightness_6_rounded),
                  title: const Text('ธีม'),
                  subtitle: Text(switch (state.themeMode) {
                    ThemeMode.light => 'สว่าง',
                    ThemeMode.dark => 'มืด',
                    ThemeMode.system => 'ตามระบบ',
                  }),
                  trailing: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: <ThemeMode>{state.themeMode},
                    onSelectionChanged: (Set<ThemeMode> value) =>
                        state.setThemeMode(value.first),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.calendar_today_rounded),
                  title: const Text('แสดงปีเป็น พ.ศ.'),
                  subtitle: Text(
                    state.buddhistYear ? 'เช่น 2569' : 'แสดงเป็น ค.ศ. เช่น 2026',
                  ),
                  value: state.buddhistYear,
                  onChanged: state.setBuddhistYear,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.checklist_rounded),
                  title: const Text('แสดงงานที่เสร็จแล้ว'),
                  value: state.showCompleted,
                  onChanged: state.setShowCompleted,
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'การแจ้งเตือน & ปลุก',
            icon: Icons.notifications_active_rounded,
          ),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.verified_user_rounded),
                  title: const Text('ขอสิทธิ์แจ้งเตือน / ตั้งเวลาแม่นยำ'),
                  subtitle: const Text(
                    'ต้องอนุญาตเพื่อให้การเตือนและเสียงปลุกทำงานตรงเวลา',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final bool granted = await NotificationService.instance
                        .requestPermissions();
                    if (!context.mounted) return;
                    showSnack(
                      context,
                      granted
                          ? 'อนุญาตเรียบร้อย'
                          : 'ยังไม่ได้รับสิทธิ์ — เปิดได้ในตั้งค่าระบบ',
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.music_note_rounded),
                  title: const Text('เสียงปลุกเริ่มต้น'),
                  subtitle: Text(
                    state.defaultSoundName ??
                        'ใช้เสียงปลุกของระบบ (เลือกเสียงจากเครื่องได้)',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String value) async {
                      PickedSound? picked;
                      switch (value) {
                        case 'system':
                          picked = await SoundService.instance.pickSystemSound(
                            currentUri: state.defaultSoundUri,
                          );
                        case 'file':
                          picked = await SoundService.instance.pickAudioFile();
                        case 'preview':
                          final String? uri = state.defaultSoundUri;
                          if (uri != null) {
                            await SoundService.instance.preview(uri);
                          }
                          return;
                        case 'clear':
                          await state.setDefaultSound(null, null);
                          return;
                      }
                      if (picked != null) {
                        await state.setDefaultSound(picked.uri, picked.name);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'system',
                        child: Text('เลือกจากเสียงในระบบ'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'file',
                        child: Text('เลือกไฟล์เสียงในเครื่อง'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'preview',
                        child: Text('ลองฟัง'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'clear',
                        child: Text('ใช้เสียงระบบ'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'ข้อมูล (SQLite)',
            subtitle: 'สำรองและย้ายข้อมูลระหว่างเครื่อง',
            icon: Icons.storage_rounded,
          ),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.save_alt_rounded),
                  title: const Text('Export เป็นไฟล์ JSON'),
                  subtitle: const Text('บันทึกลงเครื่อง'),
                  onTap: () async {
                    try {
                      final String? path = await state.exportToFile();
                      if (!context.mounted) return;
                      showSnack(
                        context,
                        path == null ? 'ยกเลิกการบันทึก' : 'บันทึกไฟล์สำรองแล้ว',
                      );
                    } catch (error) {
                      if (context.mounted) {
                        showSnack(context, 'บันทึกไม่สำเร็จ: $error');
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('แชร์ไฟล์สำรอง'),
                  subtitle: const Text('ส่งเข้าอีเมล / Drive / แอปอื่น'),
                  onTap: () async {
                    try {
                      await state.shareBackup();
                    } catch (error) {
                      if (context.mounted) {
                        showSnack(context, 'แชร์ไม่สำเร็จ: $error');
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_rounded),
                  title: const Text('Import จากไฟล์'),
                  subtitle: const Text('เลือกได้ว่าจะรวมข้อมูลหรือเขียนทับ'),
                  onTap: () => _import(context, state),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'ล้างข้อมูลทั้งหมด',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () async {
                    final bool ok = await confirmDialog(
                      context,
                      title: 'ล้างข้อมูลทั้งหมด?',
                      message:
                          'งาน โฟลเดอร์ กิจวัตร ไอเดีย และการเตือนทั้งหมดจะถูกลบถาวร',
                      confirmLabel: 'ล้างข้อมูล',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    await state.clearAllData();
                    if (context.mounted) showSnack(context, 'ล้างข้อมูลแล้ว');
                  },
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'เกี่ยวกับแอป',
            subtitle: 'เวอร์ชันและการอัปเดต',
            icon: Icons.info_outline_rounded,
          ),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.system_update_rounded),
              title: const Text('ตรวจสอบอัปเดตแอป'),
              subtitle: Text('เวอร์ชัน ${AppInfo.version} • อัปเดตจาก GitHub Releases'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const UpdatePage()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Ourobask • เก็บงาน กิจวัตร และไอเดียไว้ที่เดียว',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final bool? replace = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Import ข้อมูล'),
        content: const Text('ต้องการรวมข้อมูลเข้ากับของเดิม หรือเขียนทับข้อมูลทั้งหมด?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('รวมข้อมูล'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('เขียนทับ'),
          ),
        ],
      ),
    );
    if (replace == null) return;
    try {
      final ImportResult? result = await state.importFromFile(replace: replace);
      if (!context.mounted) return;
      showSnack(
        context,
        result == null ? 'ยกเลิกการนำเข้า' : 'นำเข้าสำเร็จ • ${result.summary}',
      );
    } catch (error) {
      if (context.mounted) showSnack(context, 'นำเข้าไม่สำเร็จ: $error');
    }
  }
}
