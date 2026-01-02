import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:file_picker/file_picker.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart' as pdp;
import 'package:intl/intl.dart' as intl;
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

  Future<void> _pickAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachments.add(result.files.single.path!);
      });
    }
  }

  Widget _buildIconOrEmoji(dynamic iconData, {required double size, Color? color}) {
    if (iconData is String) {
      return Text(iconData, style: TextStyle(fontSize: size));
    }
    return HugeIcon(icon: iconData, size: size, color: color);
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
          
          if (_step == 1) _buildStep1(theme) else _buildStep2(theme),
        ],
      ),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    final jalali = Jalali.fromDateTime(_selectedDate);
    final f = jalali.formatter;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'حالت چطوره؟',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _moods.map((m) {
              final isSelected = _selectedMood == m['level'];
              return GestureDetector(
                onTap: () => _onMoodSelected(m),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? m['color'] : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (m['color'] as Color).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: _buildIconOrEmoji(
                        m['icon'],
                        size: 32,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m['label'],
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected ? m['color'] : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nextStep,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('ادامه'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ThemeData theme) {
    final activityState = ref.watch(activityProvider);
    final moodColor = _moods.firstWhere((m) => m['level'] == _selectedMood)['color'] as Color;

    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _step = 1),
                  icon: const Icon(Icons.arrow_back),
                ),
                Text(
                  'جزئیات',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 48), // Balance
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories & Activities
                  ...activityState.categories.map((cat) {
                    final activities = activityState.activities.where((a) => a.categoryId == cat.id).toList();
                    if (activities.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              _buildIconOrEmoji(
                                _getIconData(cat.iconName), 
                                size: 18, 
                                color: theme.colorScheme.primary
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cat.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: activities.map((activity) {
                            final isSelected = _selectedActivityIds.contains(activity.id);
                            return FilterChip(
                              label: Text(activity.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedActivityIds.add(activity.id!);
                                  } else {
                                    _selectedActivityIds.remove(activity.id);
                                  }
                                });
                              },
                              avatar: isSelected ? null : _buildIconOrEmoji(_getIconData(activity.iconName), size: 16, color: theme.colorScheme.onSurfaceVariant),
                              selectedColor: moodColor.withValues(alpha: 0.2),
                              checkmarkColor: moodColor,
                              labelStyle: TextStyle(
                                color: isSelected ? moodColor : theme.colorScheme.onSurface,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? moodColor : theme.colorScheme.outlineVariant,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),

                  const Divider(),
                  
                  // Note
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'یادداشت (اختیاری)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Attachments
                  Row(
                    children: [
                      IconButton(
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedAttachment01, size: 24),
                        onPressed: _pickAttachment,
                      ),
                      const SizedBox(width: 8),
                      if (_attachments.isNotEmpty)
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _attachments.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: HugeIcon(icon: HugeIcons.strokeRoundedFile01, size: 20),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Text(
                          'ضمیمه کردن فایل...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                    
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // Submit Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: moodColor,
                ),
                child: const Text('ثبت'),
              ),
            ),
          ),
        ],
      ),
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
