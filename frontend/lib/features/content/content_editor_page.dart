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
import '../../core/social_share.dart';
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
  Uint8List? _photoBytes;
  bool _instagramConfigured = false;
  bool _instagramConnected = false;
  String _instagramUsername = '';

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.item);
    _body = TextEditingController(text: _item['body'] as String? ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInstagramStatus());
  }

  Future<void> _loadInstagramStatus() async {
    try {
      final result = Map<String, dynamic>.from(
        await context.read<AuthController>().api.get(
          'integrations/instagram/status/',
        ),
      );
      if (!mounted) return;
      setState(() {
        _instagramConfigured = result['configured'] == true;
        _instagramConnected = result['connected'] == true;
        _instagramUsername = result['username'] as String? ?? '';
      });
    } on ApiException {
      // The editor remains usable for drafts if Instagram is not configured.
    }
  }

  Future<void> _chooseInstagramPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'We could not read that photo. Choose it again.');
      return;
    }
    if (file.size > 20 * 1024 * 1024) {
      setState(() => _error = 'Choose a photo smaller than 20 MB.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uploaded = Map<String, dynamic>.from(
        await context.read<AuthController>().api.upload(
          'integrations/content/${_item['id']}/image/',
          fields: const {},
          fileName: file.name,
          bytes: bytes,
        ),
      );
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _item = {..._item, ...uploaded};
      });
      _toast('Photo added to this draft.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectInstagram() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = Map<String, dynamic>.from(
        await context.read<AuthController>().api.post(
          'integrations/instagram/connect/',
        ),
      );
      final url = result['authorization_url'] as String?;
      if (url == null || !openUrlInCurrentTab(url)) {
        throw const ApiException('Could not open Instagram authorization.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishInstagram() async {
    if (_item['image_url'] == null || (_item['image_url'] as String).isEmpty) {
      setState(() => _error = 'Choose a photo before publishing.');
      return;
    }
    if (!_instagramConnected) {
      setState(
        () => _error =
            'Connect your Instagram Creator or Business account first.',
      );
      return;
    }
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Add a caption before publishing.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish to Instagram now?'),
        content: Text(
          'This will publish the selected photo and caption to @$_instagramUsername immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(showMessage: false);
    if (!mounted || _error != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _item = Map<String, dynamic>.from(
        await context.read<AuthController>().api.post(
          'integrations/content/${_item['id']}/publish/',
          {'caption': _body.text.trim()},
        ),
      );
      if (mounted) {
        setState(() {});
        _toast('Your photo and caption were published to Instagram.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save({bool showMessage = true}) async {
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Your content cannot be empty.');
      return;
    }
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
      if (!mounted) return;
      _body.text = _item['body'] as String? ?? _body.text;
      if (showMessage && mounted) _toast('Changes saved.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate() async {
    if (_body.text.trim() != (_item['body'] as String? ?? '').trim()) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace your unsaved edits?'),
          content: const Text(
            'Regenerating creates a fresh version from the original source. Save or copy your edits first if you want to keep them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
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
      if (!mounted) return;
      _body.text = _item['body'] as String? ?? '';
      if (mounted) _toast('A refreshed version is ready to review.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    if (_body.text.trim().isEmpty) {
      _toast('Add some text before copying.');
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: _body.text));
      if (mounted) _toast('Copied to clipboard.');
    } catch (_) {
      if (mounted) {
        _toast('Could not access the clipboard. Select and copy the text.');
      }
    }
  }

  Future<void> _shareTo(
    String platform, {
    required bool opened,
    required Future<void> copied,
  }) async {
    if (_body.text.trim().isEmpty) {
      _toast('Add some text before sharing.');
      return;
    }
    try {
      await copied;
      if (!mounted) return;
      _toast(
        opened
            ? 'Caption copied. Paste it into your ${titleCase(platform)} post.'
            : 'Caption copied. Open ${titleCase(platform)} and paste it into your post.',
      );
    } catch (_) {
      if (mounted) {
        _toast(
          opened
              ? 'Opened ${titleCase(platform)}. Copy the caption before posting.'
              : 'Could not copy the caption. Use Copy, then post it manually.',
        );
      }
    }
  }

  Future<void> _showShareOptions() async {
    final choice =
        await showModalBottomSheet<
          ({String platform, bool opened, Future<void> copied})
        >(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share your draft',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'We’ll copy your text. On web, the platform opens in a new tab; on phone, switch to its app and paste your caption.',
                  ),
                  const SizedBox(height: 16),
                  for (final entry in const [
                    ('instagram', 'Instagram', Icons.camera_alt_outlined),
                    ('facebook', 'Facebook', Icons.groups_outlined),
                    ('linkedin', 'LinkedIn', Icons.work_outline_rounded),
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.violetSoft,
                        child: Icon(entry.$3, color: AppColors.violet),
                      ),
                      title: Text(entry.$2),
                      subtitle: const Text(
                        'Copy caption and continue to the platform',
                      ),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                      onTap: () {
                        if (_body.text.trim().isEmpty) {
                          Navigator.pop(context);
                          _toast('Add some text before sharing.');
                          return;
                        }
                        final copied = Clipboard.setData(
                          ClipboardData(text: _body.text.trim()),
                        );
                        final opened = openSocialPlatform(entry.$1);
                        Navigator.pop(context, (
                          platform: entry.$1,
                          opened: opened,
                          copied: copied,
                        ));
                      },
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'This is a manual share. ReContent has not connected or published to your account.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
    if (choice != null) {
      await _shareTo(
        choice.platform,
        opened: choice.opened,
        copied: choice.copied,
      );
    }
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
      if (mounted) {
        _toast('Could not save the file. You can copy the text instead.');
      }
    }
  }

  Future<void> _schedule() async {
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Add some text before planning a post.');
      return;
    }
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
      _item = Map<String, dynamic>.from(
        await api.patch('content/${_item['id']}/', {'body': _body.text.trim()}),
      );
      if (!mounted) return;
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
      if (mounted) {
        _toast('Planned time saved. Automatic publishing is not connected.');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSchedule() async {
    final id = _item['schedule_id'];
    if (id == null) {
      _toast('There is no planned time to cancel.');
      return;
    }
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
      if (mounted) setState(() => _error = error.message);
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
      if (mounted) setState(() => _error = error.message);
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
      await context.read<AuthController>().api.delete(
        'content/${_item['id']}/',
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
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
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.violetSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 520;
                          final action = FilledButton.icon(
                            onPressed: _busy ? null : _showShareOptions,
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Share manually'),
                          );
                          return compact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _ShareExplanation(),
                                    const SizedBox(height: 12),
                                    action,
                                  ],
                                )
                              : Row(
                                  children: [
                                    const Expanded(child: _ShareExplanation()),
                                    const SizedBox(width: 16),
                                    action,
                                  ],
                                );
                        },
                      ),
                    ),
                    if (_item['platform'] == 'instagram') ...[
                      const SizedBox(height: 16),
                      _InstagramPublishCard(
                        configured: _instagramConfigured,
                        connected: _instagramConnected,
                        username: _instagramUsername,
                        imageBytes: _photoBytes,
                        imageUrl: _item['image_url'] as String? ?? '',
                        published: _item['status'] == 'published',
                        busy: _busy,
                        onChoosePhoto: _chooseInstagramPhoto,
                        onConnect: _connectInstagram,
                        onPublish: _publishInstagram,
                      ),
                    ],
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
                        if (status != 'cancelled' && status != 'published')
                          FilledButton.icon(
                            onPressed: _busy ? null : _schedule,
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(
                              status == 'scheduled'
                                  ? 'Change planned time'
                                  : 'Plan a time',
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
                    if (status != 'cancelled' && status != 'published') ...[
                      const SizedBox(height: 12),
                      const Text(
                        'A planned time is a reminder. Use Publish now to send an Instagram post immediately.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
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

class _ShareExplanation extends StatelessWidget {
  const _ShareExplanation();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Ready to share?',
        style: TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      SizedBox(height: 4),
      Text(
        'Copy this draft and open the social app to review and publish it.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _InstagramPublishCard extends StatelessWidget {
  const _InstagramPublishCard({
    required this.configured,
    required this.connected,
    required this.username,
    required this.imageBytes,
    required this.imageUrl,
    required this.published,
    required this.busy,
    required this.onChoosePhoto,
    required this.onConnect,
    required this.onPublish,
  });

  final bool configured;
  final bool connected;
  final String username;
  final Uint8List? imageBytes;
  final String imageUrl;
  final bool published;
  final bool busy;
  final VoidCallback onChoosePhoto;
  final VoidCallback onConnect;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null || imageUrl.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publish to Instagram',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            connected
                ? 'Connected as @$username'
                : configured
                ? 'Connect your Creator or Business account to publish here.'
                : 'Meta publishing setup is not complete for this app yet.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (hasImage) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes!,
                      height: 220,
                      width: 300,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      imageUrl,
                      height: 220,
                      width: 300,
                      fit: BoxFit.cover,
                    ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onChoosePhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(hasImage ? 'Change photo' : 'Choose photo'),
              ),
              if (configured && !connected)
                OutlinedButton.icon(
                  onPressed: busy ? null : onConnect,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Connect Instagram'),
                ),
              if (connected && !published)
                FilledButton.icon(
                  onPressed: busy || !hasImage ? null : onPublish,
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text('Publish now'),
                ),
              if (published)
                const Chip(
                  avatar: Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text('Published'),
                ),
            ],
          ),
          if (!configured) ...[
            const SizedBox(height: 10),
            const Text(
              'The project owner must add a Meta app ID, app secret, redirect URL, and public HTTPS API address to the backend before this can connect.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
