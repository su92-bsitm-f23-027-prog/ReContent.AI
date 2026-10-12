import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/widgets.dart';

class ContentEditorPage extends StatefulWidget {
  const ContentEditorPage({super.key, required this.item});
  final Map<String, dynamic> item;

  @override
  State<ContentEditorPage> createState() => _ContentEditorPageState();
}

class _ContentEditorPageState extends State<ContentEditorPage> {
  late Map<String, dynamic> _item;
  late TextEditingController _body;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.item);
    _body = TextEditingController(text: _item['body'] as String? ?? '');
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save({bool showMessage = true}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _item = Map<String, dynamic>.from(
        await context.read<AuthController>().api.patch(
          'content/${_item['id']}/',
          {'body': _body.text.trim()},
        ),
      );
      _body.text = _item['body'] as String? ?? _body.text;
      if (showMessage && mounted) _toast('Changes saved.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _item = Map<String, dynamic>.from(
        await context.read<AuthController>().api.post(
          'content/${_item['id']}/regenerate/',
        ),
      );
      _body.text = _item['body'] as String? ?? '';
      if (mounted) _toast('A refreshed version is ready to review.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _body.text));
    if (mounted) _toast('Copied to clipboard.');
  }

  Future<void> _download() async {
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save your post as a text file',
        fileName: 'recontent-${_item['platform']}-${_item['id']}.txt',
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        bytes: Uint8List.fromList(utf8.encode(_body.text)),
      );
    } catch (_) {
      if (mounted)
        _toast('Could not save the file. You can copy the text instead.');
    }
  }

  Future<void> _schedule() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null || !mounted) return;
    final local = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (!local.isAfter(DateTime.now())) {
      _toast('Choose a time in the future.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<AuthController>().api;
      final scheduleId = _item['schedule_id'];
      final dynamic response = scheduleId == null
          ? await api.post('schedules/', {
              'content': _item['id'],
              'scheduled_for': local.toUtc().toIso8601String(),
            })
          : await api.patch('schedules/$scheduleId/', {
              'scheduled_for': local.toUtc().toIso8601String(),
            });
      final scheduled = Map<String, dynamic>.from(response as Map);
      _item['schedule_id'] = scheduled['id'];
      _item['scheduled_for'] = scheduled['scheduled_for'];
      _item['status'] = 'scheduled';
      if (mounted)
        _toast('Post time saved. ReContent will not publish it automatically.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSchedule() async {
    final id = _item['schedule_id'];
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel scheduled time?'),
        content: const Text(
          'The content stays in your library as a cancelled item.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel schedule'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().api.post('schedules/$id/cancel/');
      _item['status'] = 'cancelled';
      if (mounted) _toast('Schedule cancelled. Your content is still saved.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreDraft() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _item = Map<String, dynamic>.from(
        await context.read<AuthController>().api.post(
          'content/${_item['id']}/restore_draft/',
        ),
      );
      if (mounted) _toast('Restored as a draft.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this content?'),
        content: const Text(
          'This removes the saved draft and its planned schedule from your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep content'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().api.delete('content/${_item['id']}/');
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final status = _item['status'] as String? ?? 'draft';
    DateTime? scheduled;
    try {
      final raw = _item['scheduled_for'];
      if (raw is String) scheduled = DateTime.parse(raw).toLocal();
    } catch (_) {}
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Edit content'),
        actions: [
          IconButton(
            tooltip: 'Close editor',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Center(
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          titleCase(
                            _item['content_type'] as String? ?? 'caption',
                          ),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        StatusPill(status: status),
                        if (_item['generation_mode'] == 'demo')
                          const Chip(
                            label: Text('Demo mode'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Color(0xFFFFF0E5),
                            side: BorderSide.none,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${titleCase(_item['platform'] as String? ?? '')} · ${_item['source_title'] as String? ?? 'Saved content'}',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _body,
                      maxLines: 14,
                      minLines: 9,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                        labelText: 'Your content',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      InlineError(message: _error!),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save changes'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _regenerate,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Regenerate'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _download,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Download TXT'),
                        ),
                        TextButton.icon(
                          onPressed: _busy ? null : _delete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete'),
                        ),
                        if (status != 'cancelled')
                          FilledButton.icon(
                            onPressed: _busy ? null : _schedule,
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(
                              status == 'scheduled'
                                  ? 'Change time'
                                  : 'Schedule',
                            ),
                          ),
                        if (status == 'scheduled')
                          TextButton.icon(
                            onPressed: _busy ? null : _cancelSchedule,
                            icon: const Icon(Icons.event_busy_outlined),
                            label: const Text('Cancel schedule'),
                          ),
                        if (status == 'cancelled')
                          TextButton.icon(
                            onPressed: _busy ? null : _restoreDraft,
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Restore draft'),
                          ),
                      ],
                    ),
                    if (scheduled != null && status == 'scheduled') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.mintSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_available_outlined,
                              color: AppColors.mint,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              'Planned for ${DateFormat('EEE, MMM d · h:mm a').format(scheduled)}',
                              style: const TextStyle(
                                color: AppColors.mint,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
