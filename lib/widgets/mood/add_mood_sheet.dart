import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:file_picker/file_picker.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart' as pdp;
import 'package:intl/intl.dart' as intl;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../audio_waveform_player.dart';
import '../../models/mood_entry.dart';
import '../../providers/mood_provider.dart';
import '../flow_toast.dart';

class AddMoodSheet extends ConsumerStatefulWidget {
  final MoodEntry? entry;
  const AddMoodSheet({super.key, this.entry});

  @override
  ConsumerState<AddMoodSheet> createState() => _AddMoodSheetState();
}

class _AddMoodSheetState extends ConsumerState<AddMoodSheet> {
  int _step = 1;
  MoodLevel? _selectedMood;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  final Set<int> _selectedActivityIds = {};
  final List<String> _attachments = [];

  // Audio Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _selectedMood = widget.entry!.moodLevel;
      _selectedDate = widget.entry!.dateTime;
      _noteController.text = widget.entry!.note ?? '';
      _selectedActivityIds.addAll(widget.entry!.activityIds);
      _attachments.addAll(widget.entry!.attachments);
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Mood Data
  final List<Map<String, dynamic>> _moods = [
    {'level': MoodLevel.rad, 'icon': '🤩', 'color': const Color(0xFF4CAF50), 'label': 'عالی'},
    {'level': MoodLevel.good, 'icon': '😊', 'color': const Color(0xFF8BC34A), 'label': 'خوب'},
    {'level': MoodLevel.meh, 'icon': '😐', 'color': const Color(0xFF2196F3), 'label': 'معمولی'},
    {'level': MoodLevel.bad, 'icon': '☹️', 'color': const Color(0xFFFF9800), 'label': 'بد'},
    {'level': MoodLevel.awful, 'icon': '😫', 'color': const Color(0xFFF44336), 'label': 'افتضاح'},
  ];

  void _onMoodSelected(Map<String, dynamic> mood) {
    setState(() {
      _selectedMood = mood['level'];
    });
  }

  void _nextStep() {
    if (_selectedMood == null) {
      FlowToast.show(context, message: 'لطفاً حس خود را انتخاب کنید', type: FlowToastType.warning);
      return;
    }
    setState(() => _step = 2);
  }

  void _submit() {
    if (_selectedMood == null) return;

    final entry = MoodEntry(
      id: widget.entry?.id,
      dateTime: _selectedDate,
      moodLevel: _selectedMood!,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      activityIds: _selectedActivityIds.toList(),
      attachments: _attachments,
      createdAt: widget.entry?.createdAt ?? DateTime.now(),
      updatedAt: widget.entry != null ? DateTime.now() : null,
    );

    if (widget.entry != null) {
      ref.read(moodProvider.notifier).updateMood(entry);
      FlowToast.show(context, message: 'مود شما با موفقیت ویرایش شد', type: FlowToastType.success);
    } else {
      ref.read(moodProvider.notifier).addMood(entry);
      FlowToast.show(context, message: 'مود شما با موفقیت ثبت شد', type: FlowToastType.success);
    }
    Navigator.pop(context);
  }

  Future<void> _pickDateTime() async {
    final jalali = Jalali.fromDateTime(_selectedDate);
    final pickedDate = await pdp.showPersianDatePicker(
      context: context,
      initialDate: jalali,
      firstDate: Jalali(1400),
      lastDate: Jalali(1410),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate.toDateTime().add(
                Duration(hours: pickedTime.hour, minutes: pickedTime.minute),
              );
        });
      }
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        if (!mounted) return;
        FlowToast.show(
          context,
          message: 'خطا در باز کردن فایل: ${result.message}',
          type: FlowToastType.error,
        );
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      if (!mounted) return;
      FlowToast.show(
        context,
        message: 'خطا در باز کردن فایل',
        type: FlowToastType.error,
      );
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachments.add(result.files.single.path!);
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _attachments.add(path);
        });
      }
      setState(() => _isRecording = false);
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Widget _buildIconOrEmoji(dynamic iconData, {required double size, Color? color}) {
    if (iconData is String) {
      return Text(iconData, style: TextStyle(fontSize: size));
    }
    return HugeIcon(icon: iconData, size: size, color: color);
  }

  Widget _buildDividerWithTitle(String title, dynamic iconData, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: color.withValues(alpha: 0.2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconOrEmoji(iconData, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Divider(color: color.withValues(alpha: 0.2))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Flexible(
            child: Stack(
              children: [
                if (_step == 1) _buildStep1(theme) else _buildStep2(theme),
                
                // Sticky Bottom Button with Fade
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          theme.colorScheme.surface,
                          theme.colorScheme.surface.withValues(alpha: 0.8),
                          theme.colorScheme.surface.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.6, 1.0],
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _step == 1 ? _nextStep : _submit,
                        icon: HugeIcon(
                          icon: _step == 1 
                              ? HugeIcons.strokeRoundedArrowRight01 
                              : (widget.entry == null ? HugeIcons.strokeRoundedAddSquare : HugeIcons.strokeRoundedCheckmarkSquare04),
                          size: 20,
                          color: theme.colorScheme.onPrimary,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        label: Text(
                          _step == 1 ? 'ادامه' : (widget.entry == null ? 'ثبت مود' : 'ذخیره تغییرات'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    final jalali = Jalali.fromDateTime(_selectedDate);
    final f = jalali.formatter;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        children: [
          Text(
            'حالت چطوره؟',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _moods.map((m) {
              final isSelected = _selectedMood == m['level'];
              return GestureDetector(
                onTap: () => _onMoodSelected(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (m['color'] as Color).withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? (m['color'] as Color).withValues(alpha: 0.5) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildIconOrEmoji(
                        m['icon'],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m['label'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? m['color'] : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${f.d} ${f.mN} ${f.yyyy} - ${intl.DateFormat('HH:mm').format(_selectedDate)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, size: 16, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ThemeData theme) {
    final activityState = ref.watch(activityProvider);
    final moodColor = _moods.firstWhere((m) => m['level'] == _selectedMood)['color'] as Color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTaskEdit01,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'جزئیات',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _step = 1),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 22,
                  color: Colors.grey,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categories & Activities
                ...activityState.categories.map((cat) {
                  final activities = activityState.activities.where((a) => a.categoryId == cat.id).toList();
                  if (activities.isEmpty) return const SizedBox.shrink();

                  return Column(
                    children: [
                      _buildDividerWithTitle(cat.name, _getIconData(cat.iconName), theme),
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: activities.map((activity) {
                          final isSelected = _selectedActivityIds.contains(activity.id);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedActivityIds.remove(activity.id);
                                } else {
                                  _selectedActivityIds.add(activity.id!);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? moodColor.withValues(alpha: 0.15)
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? moodColor.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildIconOrEmoji(
                                    _getIconData(activity.iconName),
                                    size: 18,
                                    color: isSelected ? moodColor : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    activity.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? moodColor : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }),

                // Note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _noteController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'یادداشت...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Attachments
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedAttachment01,
                          size: 18,
                        ),
                        label: const Text('پیوست فایل'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _toggleRecording,
                        icon: HugeIcon(
                          icon: _isRecording
                              ? HugeIcons.strokeRoundedStop
                              : HugeIcons.strokeRoundedMic01,
                          size: 18,
                          color: _isRecording ? Colors.red : null,
                        ),
                        label: Text(
                          _isRecording ? 'توقف ضبط' : 'ضبط صدا',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isRecording ? Colors.red : null,
                          side: _isRecording
                              ? const BorderSide(color: Colors.red)
                              : BorderSide(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: _attachments.map((att) {
                        final name = att.split('/').last;
                        final isVoice = name.startsWith('voice_') || att.endsWith('.m4a');
                        final isImage = name.toLowerCase().endsWith('.jpg') ||
                            name.toLowerCase().endsWith('.jpeg') ||
                            name.toLowerCase().endsWith('.png') ||
                            name.toLowerCase().endsWith('.gif') ||
                            name.toLowerCase().endsWith('.webp');

                        if (isVoice) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AudioWaveformPlayer(
                              audioPath: att,
                              onDelete: () {
                                setState(() {
                                  _attachments.remove(att);
                                });
                              },
                            ),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => _openFile(att),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 48, // Same height as audio player
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    HugeIcon(
                                      icon: isImage
                                          ? HugeIcons.strokeRoundedImage01
                                          : HugeIcons.strokeRoundedFile01,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name.length > 30 ? '${name.substring(0, 30)}...' : name,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _attachments.remove(att);
                                        });
                                      },
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedCancel01,
                                        size: 18,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ),
                ],
                  
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper to map string names to HugeIcons data
  dynamic _getIconData(String name) {
    if (!name.startsWith('strokeRounded')) return name;
    switch (name) {
      case 'strokeRoundedFavourite':
        return HugeIcons.strokeRoundedFavourite;
      case 'strokeRoundedGameController02':
        return HugeIcons.strokeRoundedGameController02;
      case 'strokeRoundedSleep':
        return HugeIcons.strokeRoundedTick02; // Fallback for missing
      case 'strokeRoundedHealth':
        return HugeIcons.strokeRoundedHealth;
      case 'strokeRoundedHappy':
        return HugeIcons.strokeRoundedSent; // Fallback
      case 'strokeRoundedEnergy':
        return HugeIcons.strokeRoundedFlash;
      case 'strokeRoundedGiveLove':
        return HugeIcons.strokeRoundedFavourite; // Fallback
      case 'strokeRoundedMoon02':
        return HugeIcons.strokeRoundedMoon02;
      case 'strokeRoundedBored':
        return HugeIcons.strokeRoundedNote01; // Fallback
      case 'strokeRoundedBubbleChatDelay':
        return HugeIcons.strokeRoundedBubbleChatDelay;
      case 'strokeRoundedAngry':
        return HugeIcons.strokeRoundedAlertCircle; // Fallback
      case 'strokeRoundedSad01':
        return HugeIcons.strokeRoundedSent; // Fallback
      case 'strokeRoundedGameController03':
        return HugeIcons.strokeRoundedGameController03;
      case 'strokeRoundedClapperboard':
        return HugeIcons.strokeRoundedPlay;
      case 'strokeRoundedBookOpen01':
        return HugeIcons.strokeRoundedBookOpen01;
      case 'strokeRoundedAirplane01':
        return HugeIcons.strokeRoundedAirplane01;
      case 'strokeRoundedMusicNote01':
        return HugeIcons.strokeRoundedMusicNote01;
      case 'strokeRoundedCheers':
        return HugeIcons.strokeRoundedStar; // Fallback
      case 'strokeRoundedAlert02':
        return HugeIcons.strokeRoundedAlert02;
      case 'strokeRoundedRunning':
        return HugeIcons.strokeRoundedStar;
      case 'strokeRoundedOrganicFood':
        return HugeIcons.strokeRoundedApple; // Fallback
      case 'strokeRoundedWaterDrop':
        return HugeIcons.strokeRoundedDroplet;
      case 'strokeRoundedWalking':
        return HugeIcons.strokeRoundedUser; // Fallback
      default:
        return HugeIcons.strokeRoundedStar;
    }
  }
}
