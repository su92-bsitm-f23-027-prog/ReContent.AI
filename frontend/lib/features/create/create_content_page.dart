import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/widgets.dart';

class CreateContentPage extends StatefulWidget {
  const CreateContentPage({super.key, required this.onGenerated});
  final VoidCallback onGenerated;

  @override
  State<CreateContentPage> createState() => _CreateContentPageState();
}

class _CreateContentPageState extends State<CreateContentPage> {
  final _title = TextEditingController();
  final _sourceText = TextEditingController();
  final _transcript = TextEditingController();
  String _kind = 'text';
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  int? _sourceId;
  int _step = 0;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _analysis;
  final Set<String> _platforms = {'instagram'};
  final Set<String> _types = {'caption', 'short_post'};

  static const _platformOptions = {
    'instagram': ('Instagram', Icons.camera_alt_outlined),
    'facebook': ('Facebook', Icons.groups_outlined),
    'linkedin': ('LinkedIn', Icons.work_outline_rounded),
  };
  static const _typeOptions = {
    'caption': 'Caption',
    'hook': 'Hook',
    'title': 'Title',
    'description': 'Description',
    'hashtags': 'Hashtags',
    'short_post': 'Short post',
  };

  @override
  void dispose() {
    _title.dispose();
    _sourceText.dispose();
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _kind == 'audio'
            ? const ['mp3', 'wav', 'm4a', 'ogg', 'flac', 'webm', 'mp4']
            : const ['mp4', 'mov', 'mkv', 'webm'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.size > 20 * 1024 * 1024) {
        setState(() {
          _pickedFile = null;
          _fileBytes = null;
          _error = 'Choose a file smaller than 20 MB.';
        });
        return;
      }
      if (file.bytes == null) {
        setState(
          () => _error = 'We could not read that file. Please choose it again.',
        );
        return;
      }
      setState(() {
        _pickedFile = file;
        _fileBytes = file.bytes;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The file picker could not open. Please try again.',
        );
      }
    }
  }

  Future<void> _createAndProcess() async {
    if (_kind == 'text' && _sourceText.text.trim().isEmpty) {
      setState(() => _error = 'Add the text you want to repurpose.');
      return;
    }
    if (_kind != 'text' && (_pickedFile == null || _fileBytes == null)) {
      setState(() => _error = 'Choose an audio or video file first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<AuthController>().api;
      final sourceFirstLine = _sourceText.text
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => 'New source');
      final title = _title.text.trim().isEmpty
          ? (_pickedFile?.name ?? sourceFirstLine)
          : _title.text.trim();
      final dynamic created;
      if (_kind == 'text') {
        created = await api.post('sources/', {
          'title': title.length > 180 ? title.substring(0, 180) : title,
          'kind': 'text',
          'text': _sourceText.text.trim(),
        });
      } else {
        created = await api.upload(
          'sources/',
          fields: {
            'title': title.length > 180 ? title.substring(0, 180) : title,
            'kind': _kind,
          },
          fileName: _pickedFile!.name,
          bytes: _fileBytes!,
        );
      }
      if (!mounted) return;
      _sourceId = (created as Map)['id'] as int;
      final processed = Map<String, dynamic>.from(
        await api.post('sources/$_sourceId/process/'),
      );
      if (!mounted) return;
      final transcript = processed['transcript'];
      _transcript.text =
          transcript is Map ? transcript['text'] as String? ?? '' : '';
      _analysis = processed['analysis'] is Map
          ? Map<String, dynamic>.from(processed['analysis'] as Map)
          : null;
      if (_transcript.text.isEmpty && _kind == 'text') {
        _transcript.text = _sourceText.text.trim();
      }
      setState(() => _step = 1);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'We could not process this source. Check the file and API connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveTranscript() async {
    if (_sourceId == null || _transcript.text.trim().isEmpty) {
      setState(() => _error = 'The transcript cannot be empty.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().api.patch(
        'sources/$_sourceId/transcript/',
        {'text': _transcript.text.trim()},
      );
      if (!mounted) return;
      setState(() => _step = 2);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    if (_platforms.isEmpty || _types.isEmpty) {
      setState(
        () => _error = 'Choose at least one platform and one content type.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().api.post('generate/', {
        'source_id': _sourceId,
        'platforms': _platforms.toList(),
        'content_types': _types.toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your platform-ready drafts are saved in My content.'),
        ),
      );
      widget.onGenerated();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Content could not be generated. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
        children: [
          const SectionHeading(
            title: 'Create content',
            subtitle:
                'Start with one source. Shape it into content that fits each platform.',
          ),
          const SizedBox(height: 24),
          _StepHeader(step: _step),
          const SizedBox(height: 20),
          if (_busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              _step == 0
                  ? (_kind == 'text'
                      ? 'Analyzing your source…'
                      : 'Uploading and transcribing…')
                  : _step == 1
                      ? 'Saving your transcript…'
                      : 'Creating your drafts…',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            InlineError(message: _error!),
            const SizedBox(height: 16),
          ],
          AbsorbPointer(
            absorbing: _busy,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  0 => _sourceStep(),
                  1 => _transcriptStep(),
                  _ => _platformStep(),
                },
              ),
            ),
          ),
        ],
      );

  Widget _sourceStep() => SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a source',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            const Text(
                'Paste a transcript or upload a short audio or video file.'),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: [
                _ModeChip(
                  label: 'Text',
                  icon: Icons.notes_rounded,
                  selected: _kind == 'text',
                  onTap: () => setState(() {
                    _kind = 'text';
                    _pickedFile = null;
                    _fileBytes = null;
                    _error = null;
                  }),
                ),
                _ModeChip(
                  label: 'Audio',
                  icon: Icons.graphic_eq_rounded,
                  selected: _kind == 'audio',
                  onTap: () => setState(() {
                    _kind = 'audio';
                    _pickedFile = null;
                    _fileBytes = null;
                    _error = null;
                  }),
                ),
                _ModeChip(
                  label: 'Video',
                  icon: Icons.videocam_outlined,
                  selected: _kind == 'video',
                  onTap: () => setState(() {
                    _kind = 'video';
                    _pickedFile = null;
                    _fileBytes = null;
                    _error = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Source title (optional)',
                hintText: 'e.g. Episode 04 — Building habits',
              ),
            ),
            const SizedBox(height: 14),
            if (_kind == 'text')
              TextField(
                controller: _sourceText,
                minLines: 9,
                maxLines: 16,
                maxLength: 30000,
                decoration: const InputDecoration(
                  labelText: 'Your source text',
                  alignLabelWithHint: true,
                  hintText:
                      'Paste a transcript, article, talk notes, or a few paragraphs…',
                ),
              )
            else
              _UploadDropzone(
                  file: _pickedFile, kind: _kind, onPick: _pickFile),
            if (_kind != 'text' && _pickedFile != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _pickedFile = null;
                    _fileBytes = null;
                    _error = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Remove file'),
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 14, top: 15),
                  child: Text(
                    'Files up to 20 MB',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ),
                PrimaryAction(
                  label: _busy
                      ? (_kind == 'text' ? 'Analyzing…' : 'Transcribing…')
                      : _kind == 'text'
                          ? 'Analyze source'
                          : 'Upload & transcribe',
                  onPressed: _createAndProcess,
                  busy: _busy,
                  icon: Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _transcriptStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_analysis != null) ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.violet,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Source analysis',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _analysis!['topic'] as String? ?? 'Main topic',
                    style: const TextStyle(
                      color: AppColors.violet,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_analysis!['summary'] as String? ?? ''),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final point
                          in (_analysis!['key_points'] as List? ?? const [])
                              .take(
                        5,
                      ))
                        Chip(
                          avatar: const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: AppColors.mint,
                          ),
                          label: Text(point.toString()),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.mintSoft,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review the transcript',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Correct names or wording before creating your platform versions.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _transcript,
                  minLines: 8,
                  maxLines: 15,
                  maxLength: 30000,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    hintText: 'Your source text appears here…',
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _step = 0),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    PrimaryAction(
                      label: 'Choose platforms',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _saveTranscript,
                      busy: _busy,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _platformStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where will it go?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Each platform gets its own tone and length. Select one or more.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in _platformOptions.entries)
                      FilterChip(
                        selected: _platforms.contains(entry.key),
                        onSelected: (value) => setState(() {
                          value
                              ? _platforms.add(entry.key)
                              : _platforms.remove(entry.key);
                        }),
                        avatar: Icon(
                          entry.value.$2,
                          size: 17,
                          color: _platforms.contains(entry.key)
                              ? AppColors.violet
                              : AppColors.muted,
                        ),
                        label: Text(entry.value.$1),
                        showCheckmark: true,
                        selectedColor: AppColors.violetSoft,
                        side: BorderSide(
                          color: _platforms.contains(entry.key)
                              ? AppColors.violet
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What should we create?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Pick the formats you need. You can edit every draft afterward.',
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 9,
                  runSpacing: 2,
                  children: [
                    for (final entry in _typeOptions.entries)
                      FilterChip(
                        selected: _types.contains(entry.key),
                        onSelected: (value) => setState(() {
                          value
                              ? _types.add(entry.key)
                              : _types.remove(entry.key);
                        }),
                        label: Text(entry.value),
                        selectedColor: AppColors.violetSoft,
                        side: BorderSide(
                          color: _types.contains(entry.key)
                              ? AppColors.violet
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _step = 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    PrimaryAction(
                      label: 'Generate drafts',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: _generate,
                      busy: _busy,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Source', 'Review', 'Platforms'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                color: i <= step ? AppColors.violet : AppColors.border,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: i <= step ? AppColors.violetSoft : AppColors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: i <= step
                    ? AppColors.violet.withValues(alpha: .22)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: i < step
                      ? AppColors.violet
                      : (i == step ? AppColors.violet : AppColors.border),
                  child: i < step
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  labels[i],
                  style: TextStyle(
                    color: i <= step ? AppColors.violet : AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        avatar: Icon(icon, size: 17),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.violetSoft,
        side: BorderSide(color: selected ? AppColors.violet : AppColors.border),
      );
}

class _UploadDropzone extends StatelessWidget {
  const _UploadDropzone({
    required this.file,
    required this.kind,
    required this.onPick,
  });
  final PlatformFile? file;
  final String kind;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.border, style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              Icon(
                file == null
                    ? (kind == 'audio'
                        ? Icons.graphic_eq_rounded
                        : Icons.video_library_outlined)
                    : Icons.check_circle_outline_rounded,
                size: 32,
                color: AppColors.violet,
              ),
              const SizedBox(height: 10),
              Text(
                file?.name ?? 'Choose $kind file',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                file == null
                    ? 'MP3, WAV, M4A, MP4, MOV or WEBM · up to 20 MB'
                    : '${(file!.size / 1024 / 1024).toStringAsFixed(1)} MB · tap to change',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      );
}
