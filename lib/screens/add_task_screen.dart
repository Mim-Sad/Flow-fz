import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/task.dart';
import '../models/category_data.dart';
import '../providers/task_provider.dart';
import '../providers/category_provider.dart';
import 'package:intl/intl.dart' as intl;

class AddTaskScreen extends ConsumerStatefulWidget {
  final Task? task;
  const AddTaskScreen({super.key, this.task});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _selectedDate;
  late TaskPriority _priority;
  List<String> _selectedCategories = [];
  String? _selectedEmoji;
  List<String> _attachments = [];
  RecurrenceConfig? _recurrence;
  bool _isDetailsExpanded = false;
  
  // Audio Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingFilePath;
  bool _isPlaying = false;

  String _toPersianDigit(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = input;
    for (int i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], persianDigits[i]);
    }
    return result;
  }

  String _formatJalali(Jalali j) {
    return _toPersianDigit('${j.day} ${j.formatter.mN} ${j.year}');
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title);
    _descController = TextEditingController(text: widget.task?.description);
    _selectedDate = widget.task?.dueDate ?? DateTime.now();
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _selectedCategories = widget.task?.categories ?? 
        (widget.task?.category != null ? [widget.task!.category!] : []);
    _selectedEmoji = widget.task?.taskEmoji;
    _attachments = widget.task?.attachments ?? [];
    _recurrence = widget.task?.recurrence;
  }

  Future<void> _playVoice(String path) async {
    try {
      if (_isPlaying && _playingFilePath == path) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _playingFilePath = null;
        });
      } else {
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _isPlaying = true;
          _playingFilePath = path;
        });
        
        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _playingFilePath = null;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در پخش صدا')),
      );
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.task == null ? 'تسک جدید' : 'ویرایش تسک',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, size: 24, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title and Emoji
            Row(
              children: [
                GestureDetector(
                  onTap: _showEmojiPicker,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedEmoji ?? '😀',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'عنوان تسک',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Categories
            const Text('دسته‌بندی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, child) {
                final categoriesAsync = ref.watch(categoryProvider);
                
                return categoriesAsync.when(
                  data: (categories) {
                    final cats = categories.isEmpty ? defaultCategories : categories;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cats.map((cat) {
                        final isSelected = _selectedCategories.contains(cat.id);
                        return FilterChip(
                          label: Text('${cat.emoji} ${cat.label}'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(cat.id);
                              } else {
                                _selectedCategories.remove(cat.id);
                              }
                            });
                          },
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          selectedColor: cat.color.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? cat.color : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          showCheckmark: false,
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('خطا در بارگذاری دسته‌بندی‌ها: $err'),
                );
              },
            ),
            const SizedBox(height: 16),

            // Collapsible Details Section
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'جزئیات بیشتر',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _isDetailsExpanded,
                onExpansionChanged: (val) => setState(() => _isDetailsExpanded = val),
                children: [
                  // Description
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'توضیحات بیشتر...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date & Time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, size: 20),
                    ),
                    title: const Text('زمان انجام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${_formatJalali(Jalali.fromDateTime(_selectedDate))} • ${_toPersianDigit(intl.DateFormat('HH:mm').format(_selectedDate))}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final pickedDate = await showPersianDatePicker(
                          context: context,
                          initialDate: Jalali.fromDateTime(_selectedDate),
                          firstDate: Jalali.fromDateTime(DateTime.now().subtract(const Duration(days: 365))),
                          lastDate: Jalali.fromDateTime(DateTime.now().add(const Duration(days: 365 * 2))),
                        );
                        if (pickedDate != null) {
                          if (!context.mounted) return;
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedDate),
                          );
                          
                          if (pickedTime != null) {
                            final dt = pickedDate.toDateTime();
                            setState(() {
                              _selectedDate = DateTime(
                                dt.year,
                                dt.month,
                                dt.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: const Text('تغییر'),
                    ),
                  ),
                  
                  // Recurrence
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedRepeat, size: 20, color: Colors.orange),
                    ),
                    title: const Text('تکرار', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      _getRecurrenceText(),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    trailing: TextButton(
                      onPressed: _showRecurrencePicker,
                      child: const Text('تنظیم'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Priority
                  const Text('اولویت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<TaskPriority>(
                      segments: const [
                        ButtonSegment(
                          value: TaskPriority.low, 
                          label: Text('کم'), 
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, color: Colors.green, size: 18)
                        ),
                        ButtonSegment(
                          value: TaskPriority.medium, 
                          label: Text('متوسط'),
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedMinusSign, color: Colors.orange, size: 18)
                        ),
                        ButtonSegment(
                          value: TaskPriority.high, 
                          label: Text('بالا'),
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedAlertCircle, color: Colors.red, size: 18)
                        ),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (val) {
                        setState(() => _priority = val.first);
                      },
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Attachments
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedAttachment01, size: 18),
                        label: const Text('پیوست فایل'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _toggleRecording,
                        icon: HugeIcon(
                          icon: _isRecording ? HugeIcons.strokeRoundedSquare01 : HugeIcons.strokeRoundedMic01, 
                          size: 18,
                          color: _isRecording ? Colors.red : null,
                        ),
                        label: Text(_isRecording ? 'توقف ضبط' : 'ضبط صدا'),
                        style: _isRecording ? OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ) : null,
                      ),
                    ],
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _attachments.map((att) {
                        final name = att.split('/').last;
                        final isVoice = name.startsWith('voice_') || att.endsWith('.m4a');
                        final isPlayingThis = _isPlaying && _playingFilePath == att;
                        
                        return InputChip(
                          label: Text(name.length > 20 ? '${name.substring(0, 20)}...' : name),
                          avatar: isVoice 
                              ? (isPlayingThis 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                                  : const HugeIcon(icon: HugeIcons.strokeRoundedPlay, size: 18))
                              : const HugeIcon(icon: HugeIcons.strokeRoundedFile01, size: 16),
                          onPressed: isVoice ? () => _playVoice(att) : null,
                          onDeleted: () {
                            if (isPlayingThis) {
                              _audioPlayer.stop();
                              setState(() {
                                _isPlaying = false;
                                _playingFilePath = null;
                              });
                            }
                            setState(() {
                              _attachments.remove(att);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _saveTask,
                child: Text(widget.task == null ? 'ثبت و شروع کار' : 'ذخیره تغییرات'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: 350,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('انتخاب ایموجی', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedEmoji = null);
                    Navigator.pop(context);
                  },
                  child: const Text('حذف ایموجی'),
                ),
              ],
            ),
            Expanded(
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  setState(() => _selectedEmoji = emoji.emoji);
                  Navigator.pop(context);
                },
                config: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 28,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRecurrenceText() {
    if (_recurrence == null || _recurrence!.type == RecurrenceType.none) {
      return 'بدون تکرار';
    }
    
    // Use start date (dueDate) as base
    final jStartDate = Jalali.fromDateTime(_selectedDate);
    String baseDateText = 'شروع: ${_formatJalali(jStartDate)}';

    String endDateText = '';
    if (_recurrence!.endDate != null) {
      final jEndDate = Jalali.fromDateTime(_recurrence!.endDate!);
      endDateText = ' (تا ${_formatJalali(jEndDate)})';
    }

    String typeText = '';
    switch (_recurrence!.type) {
      case RecurrenceType.hourly: typeText = 'ساعتی'; break;
      case RecurrenceType.daily: typeText = 'روزانه'; break;
      case RecurrenceType.weekly: typeText = 'هفتگی'; break;
      case RecurrenceType.monthly: typeText = 'ماهانه'; break;
      case RecurrenceType.yearly: typeText = 'سالانه'; break;
      case RecurrenceType.custom: typeText = 'هر ${_recurrence!.interval} روز'; break;
      case RecurrenceType.specificDays: 
        final days = _recurrence!.daysOfWeek?.map((d) => _getDayName(d)).join('، ') ?? '';
        typeText = 'روزهای $days'; 
        break;
      default: typeText = 'سفارشی';
    }
    return '$typeText - $baseDateText$endDateText';
  }
  
  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday: return 'شنبه';
      case DateTime.sunday: return '۱شنبه';
      case DateTime.monday: return '۲شنبه';
      case DateTime.tuesday: return '۳شنبه';
      case DateTime.wednesday: return '۴شنبه';
      case DateTime.thursday: return '۵شنبه';
      case DateTime.friday: return 'جمعه';
      default: return '';
    }
  }

  void _showRecurrencePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تنظیمات تکرار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                _buildRecurrenceOption(RecurrenceType.none, 'بدون تکرار', setSheetState),
                _buildRecurrenceOption(RecurrenceType.daily, 'روزانه', setSheetState),
                _buildRecurrenceOption(RecurrenceType.weekly, 'هفتگی', setSheetState),
                _buildRecurrenceOption(RecurrenceType.monthly, 'ماهانه', setSheetState),
                _buildRecurrenceOption(RecurrenceType.yearly, 'سالانه', setSheetState),
                _buildRecurrenceOption(RecurrenceType.specificDays, 'روزهای خاص هفته', setSheetState),
                
                if (_recurrence?.type == RecurrenceType.specificDays)
                   _buildSpecifiDaysSelector(setSheetState),
                   
                const Divider(),
                ListTile(
                  title: const Text('تاریخ پایان تکرار'),
                  subtitle: Text(_recurrence?.endDate != null 
                    ? _formatJalali(Jalali.fromDateTime(_recurrence!.endDate!))
                    : 'نامحدود'
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showPersianDatePicker(
                        context: context,
                        initialDate: Jalali.fromDateTime(_recurrence?.endDate ?? DateTime.now().add(const Duration(days: 30))),
                        firstDate: Jalali.fromDateTime(DateTime.now()),
                        lastDate: Jalali(1500, 1, 1),
                      );
                      if (picked != null) {
                        setState(() {
                          // Update recurrence with new end date
                          _recurrence = RecurrenceConfig(
                            type: _recurrence?.type ?? RecurrenceType.daily,
                            interval: _recurrence?.interval,
                            daysOfWeek: _recurrence?.daysOfWeek,
                            specificDates: _recurrence?.specificDates,
                            dayOfMonth: _recurrence?.dayOfMonth,
                            endDate: picked.toDateTime(),
                          );
                        });
                        setSheetState(() {});
                      }
                    },
                    child: const Text('تغییر'),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }
  
  Widget _buildSpecifiDaysSelector(StateSetter setSheetState) {
    final days = [
      {'id': DateTime.saturday, 'label': 'ش'},
      {'id': DateTime.sunday, 'label': '۱ش'},
      {'id': DateTime.monday, 'label': '۲ش'},
      {'id': DateTime.tuesday, 'label': '۳ش'},
      {'id': DateTime.wednesday, 'label': '۴ش'},
      {'id': DateTime.thursday, 'label': '۵ش'},
      {'id': DateTime.friday, 'label': 'ج'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: days.map((day) {
          final dayId = day['id'] as int;
          final isSelected = _recurrence?.daysOfWeek?.contains(dayId) ?? false;
          return ChoiceChip(
            label: Text(day['label'] as String),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                final currentDays = List<int>.from(_recurrence?.daysOfWeek ?? []);
                if (selected) {
                  currentDays.add(dayId);
                } else {
                  currentDays.remove(dayId);
                }
                _recurrence = RecurrenceConfig(
                  type: RecurrenceType.specificDays,
                  daysOfWeek: currentDays,
                  endDate: _recurrence?.endDate,
                );
              });
              setSheetState(() {});
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecurrenceOption(RecurrenceType type, String label, StateSetter setSheetState) {
    final isSelected = (_recurrence?.type ?? RecurrenceType.none) == type;
    return ListTile(
      title: Text(label),
      leading: HugeIcon(
        icon: isSelected ? HugeIcons.strokeRoundedCheckmarkCircle03 : HugeIcons.strokeRoundedCircle,
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
        size: 24,
      ),
      onTap: () {
        setState(() {
          if (type == RecurrenceType.none) {
            _recurrence = null;
          } else {
            // Preserve end date if switching types
            _recurrence = RecurrenceConfig(
              type: type,
              interval: 1,
              endDate: _recurrence?.endDate,
              // Default specific days to current day if switching to specificDays
              daysOfWeek: type == RecurrenceType.specificDays ? [_selectedDate.weekday] : null,
            );
          }
        });
        setSheetState(() {});
        // Don't close immediately if selecting specific days, let user pick days
        if (type != RecurrenceType.specificDays) {
          Navigator.pop(context);
        }
      },
    );
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        _attachments.add(file.path);
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
        final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  void _saveTask() {
    if (_titleController.text.isEmpty) return;
    
    final task = Task(
      id: widget.task?.id,
      title: _titleController.text,
      description: _descController.text,
      dueDate: _selectedDate,
      priority: _priority,
      categories: _selectedCategories,
      category: _selectedCategories.isNotEmpty ? _selectedCategories.first : null,
      status: widget.task?.status ?? TaskStatus.pending,
      createdAt: widget.task?.createdAt,
      taskEmoji: _selectedEmoji,
      attachments: _attachments,
      recurrence: _recurrence,
    );
    
    if (widget.task == null) {
      ref.read(tasksProvider.notifier).addTask(task);
    } else {
      ref.read(tasksProvider.notifier).updateTask(task);
    }
    Navigator.pop(context);
  }
}
