import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../utils/formatters.dart';
import 'widgets/common.dart';

/// ตรวจหาอัปเดตอัตโนมัติตอนเปิดแอป (เงียบ ๆ — ไม่มีเวอร์ชันใหม่ก็ไม่รบกวน)
Future<void> maybeAutoCheckForUpdate(BuildContext context) async {
  final UpdateService service = UpdateService.instance;
  if (!service.canInstallInApp) return;
  final AppState state = context.read<AppState>();
  if (!state.updateAutoCheck) return;
  final DateTime? last = state.updateLastCheck;
  if (last != null && DateTime.now().difference(last) < const Duration(hours: 12)) {
    return;
  }
  try {
    final UpdateCheck check = await service.checkForUpdate();
    await state.markUpdateChecked();
    final ReleaseInfo? release = check.release;
    if (!check.hasUpdate || release == null) return;
    if (state.updateSkippedVersion == release.tag) return;
    if (!context.mounted) return;
    await showUpdateSheet(context, release, currentVersion: check.currentVersion);
  } on UpdateException {
    // ตอนเปิดแอปไม่ต้องแจ้งเตือนถ้าเน็ตไม่ดี — ผู้ใช้กดตรวจเองได้ในหน้าตั้งค่า
  }
}

Future<void> showUpdateSheet(
  BuildContext context,
  ReleaseInfo release, {
  AppVersion? currentVersion,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) =>
        _UpdateSheet(release: release, currentVersion: currentVersion),
  );
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({required this.release, this.currentVersion});

  final ReleaseInfo release;
  final AppVersion? currentVersion;

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  final UpdateService _service = UpdateService.instance;

  bool _busy = false;
  bool _needPermission = false;
  int _received = 0;
  int _total = -1;
  String? _error;
  File? _file;

  double? get _progress {
    if (!_busy || _total <= 0) return null;
    return (_received / _total).clamp(0.0, 1.0);
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
      _received = 0;
      _total = -1;
    });
    try {
      final List<String> abis = await _service.deviceAbis();
      final ReleaseAsset? asset = widget.release.apkFor(abis);
      if (asset == null) {
        throw const UpdateException('รีลีสนี้ไม่มีไฟล์ APK ให้ติดตั้ง');
      }
      final File file = await _service.downloadApk(
        asset,
        onProgress: (int received, int total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _file = file;
        _busy = false;
      });
      await _install();
    } on UpdateException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  Future<void> _install() async {
    final File? file = _file;
    if (file == null) return;
    final bool allowed = await _service.canRequestInstalls();
    if (!mounted) return;
    if (!allowed) {
      setState(() => _needPermission = true);
      return;
    }
    try {
      await _service.installApk(file);
      if (!mounted) return;
      setState(() => _needPermission = false);
    } on UpdateException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _openPermissionSettings() async {
    try {
      await _service.openInstallPermissionSettings();
    } on UpdateException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.read<AppState>();
    final ReleaseInfo release = widget.release;
    final ReleaseAsset? asset = release.apks.isEmpty ? null : release.apks.first;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'มีเวอร์ชันใหม่ ${release.tag}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              <String>[
                if (widget.currentVersion != null)
                  'ตอนนี้ใช้ ${widget.currentVersion} • ใหม่ ${release.version}',
                if (release.publishedAt != null)
                  'ออกเมื่อ ${Fmt.date(release.publishedAt!.toLocal())}',
                if (asset != null && asset.size > 0) Fmt.fileSize(asset.size),
              ].join(' • '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (release.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: Text(release.notes, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
            if (_busy) ...<Widget>[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                _total > 0
                    ? 'กำลังดาวน์โหลด ${Fmt.fileSize(_received)} / ${Fmt.fileSize(_total)}'
                    : 'กำลังดาวน์โหลด ${Fmt.fileSize(_received)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_needPermission) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                'ต้องอนุญาต "ติดตั้งแอปที่ไม่รู้จัก" ให้ Ourobask ก่อน'
                ' แล้วกลับมากดติดตั้งอีกครั้ง',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _openPermissionSettings,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('เปิดหน้าตั้งค่าสิทธิ์'),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await state.skipUpdateVersion(release.tag);
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('ข้ามเวอร์ชันนี้'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('ไว้ทีหลัง'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : (_file == null ? _download : _install),
                  icon: Icon(
                    _file == null ? Icons.download_rounded : Icons.install_mobile_rounded,
                    size: 18,
                  ),
                  label: Text(_file == null ? 'ดาวน์โหลดและติดตั้ง' : 'ติดตั้งเลย'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// หน้า "เกี่ยวกับแอปและอัปเดต" — ตรวจสอบรีลีสใหม่จาก GitHub ด้วยตัวเอง
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final UpdateService _service = UpdateService.instance;

  String _current = AppInfo.version;
  bool _checking = false;
  String? _error;
  UpdateCheck? _result;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final String version = await _service.currentVersionName();
    if (!mounted) return;
    setState(() => _current = version);
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _result = null;
    });
    final AppState state = context.read<AppState>();
    try {
      final UpdateCheck check = await _service.checkForUpdate();
      await state.markUpdateChecked();
      if (!mounted) return;
      setState(() {
        _result = check;
        _checking = false;
      });
      final ReleaseInfo? release = check.release;
      if (check.hasUpdate && release != null && mounted) {
        await showUpdateSheet(context, release, currentVersion: check.currentVersion);
      }
    } on UpdateException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _checking = false;
      });
    }
  }

  String _resultText(UpdateCheck check) {
    switch (check.status) {
      case UpdateStatus.available:
        return 'มีเวอร์ชันใหม่ ${check.release?.tag ?? ''} ให้อัปเดต';
      case UpdateStatus.upToDate:
        return 'ใช้เวอร์ชันล่าสุดอยู่แล้ว';
      case UpdateStatus.noRelease:
        return 'ยังไม่มีรีลีสบน GitHub';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final DateTime? last = state.updateLastCheck;
    final UpdateCheck? result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('เกี่ยวกับแอป & อัปเดต')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppInfo.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'เวอร์ชัน $_current',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppInfo.repoSlug,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: 'อัปเดตแอป',
            subtitle: 'ตรวจรีลีสใหม่จาก GitHub แล้วติดตั้งได้ในแอปเลย',
            icon: Icons.system_update_rounded,
          ),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.cloud_download_rounded),
                  title: const Text('ตรวจสอบตอนนี้'),
                  subtitle: Text(
                    last == null
                        ? 'ยังไม่เคยตรวจสอบ'
                        : 'ตรวจล่าสุด ${Fmt.date(last)} ${Fmt.time(last)} น.',
                  ),
                  trailing: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _checking ? null : _check,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew_rounded),
                  title: const Text('ตรวจอัตโนมัติเมื่อเปิดแอป'),
                  subtitle: const Text(
                    'ตรวจให้วันละครั้ง ถ้ามีเวอร์ชันใหม่จะแจ้งให้ทราบ',
                  ),
                  value: state.updateAutoCheck,
                  onChanged: state.setUpdateAutoCheck,
                ),
                if (state.updateSkippedVersion != null) ...<Widget>[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.unpublished_rounded),
                    title: Text('ข้ามเวอร์ชัน ${state.updateSkippedVersion} ไว้'),
                    subtitle: const Text('แตะเพื่อเลิกข้าม แล้วให้แจ้งเตือนอีกครั้ง'),
                    onTap: () => state.skipUpdateVersion(null),
                  ),
                ],
              ],
            ),
          ),
          if (result != null || _error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                color: theme.colorScheme.surfaceContainerLow,
                child: ListTile(
                  leading: Icon(
                    _error != null
                        ? Icons.error_outline_rounded
                        : (result!.hasUpdate
                              ? Icons.new_releases_rounded
                              : Icons.verified_rounded),
                    color: _error != null ? theme.colorScheme.error : null,
                  ),
                  title: Text(_error ?? _resultText(result!)),
                  trailing: result != null && result.hasUpdate
                      ? FilledButton(
                          onPressed: () => showUpdateSheet(
                            context,
                            result.release!,
                            currentVersion: result.currentVersion,
                          ),
                          child: const Text('อัปเดต'),
                        )
                      : null,
                ),
              ),
            ),
          if (!_service.canInstallInApp)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'การติดตั้งอัตโนมัติในแอปรองรับเฉพาะ Android'
                ' — บนระบบอื่นให้ดาวน์โหลดจากหน้า Releases เอง',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SelectableText(
              AppInfo.releasesUrl,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
