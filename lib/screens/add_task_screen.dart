import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
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
  final DateTime? initialDate;
  const AddTaskScreen({super.key, this.task, this.initialDate});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _tagController;
  late DateTime _selectedDate;
  late TaskPriority _priority;
  List<String> _selectedCategories = [];
  List<String> _tags = [];
  String? _selectedEmoji;
  List<String> _attachments = [];
  RecurrenceConfig? _recurrence;
  bool _isDetailsExpanded = false;
  bool _hasTime = false;
  
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
    _tagController = TextEditingController();
    
    _recurrence = widget.task?.recurrence;
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _selectedCategories = widget.task?.categories ?? 
        (widget.task?.category != null ? [widget.task!.category!] : []);
    _tags = List.from(widget.task?.tags ?? []);
    _selectedEmoji = widget.task?.taskEmoji;
    _attachments = widget.task?.attachments ?? [];
    
    if (widget.task != null) {
      _hasTime = widget.task!.metadata['hasTime'] ?? true;
    } else {
      _hasTime = false;
    }

    // Logic for date:
    // 1. If it's a new task (no task provided):
    //    - Use initialDate (date user clicked on) or now.
    // 2. If it's a duplicated task (task provided but no ID):
    //    - Use initialDate but preserve time from original task if possible.
    // 3. If it's an existing task (edit, has ID):
    //    - ALWAYS use the task's original dueDate. initialDate should be ignored for edits.

    final isNew = widget.task == null;
    final isDuplicated = widget.task != null && widget.task!.id == null;

    if (isNew) {
      _selectedDate = widget.initialDate ?? DateTime.now();
    } else if (isDuplicated) {
      final isRecurring = widget.task!.recurrence != null && widget.task!.recurrence!.type != RecurrenceType.none;
      
      if (isRecurring) {
        // For recurring tasks, we want to preserve the original start date of the series
        final allTasks = ref.read(tasksProvider);
        final duplicatedFromId = widget.task!.metadata['duplicatedFromId'];
        final originalTask = allTasks.cast<Task?>().firstWhere(
          (t) => t?.id == duplicatedFromId,
          orElse: () => null,
        );
        
        if (originalTask != null) {
          _selectedDate = originalTask.dueDate;
        } else {
          _selectedDate = widget.task!.dueDate;
        }
      } else {
        // For normal tasks, we can use the target date (e.g. today or selected date)
        final originalDate = widget.task!.dueDate;
        final targetDate = widget.initialDate ?? originalDate;
        _selectedDate = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          originalDate.hour,
          originalDate.minute,
        );
      }
      
      // If duplicated task's start date is after its recurrence end date, clear the end date
      if (_recurrence?.endDate != null && _selectedDate.isAfter(_recurrence!.endDate!)) {
        _recurrence = RecurrenceConfig(
          type: _recurrence!.type,
          interval: _recurrence!.interval,
          daysOfWeek: _recurrence!.daysOfWeek,
          specificDates: _recurrence!.specificDates,
          dayOfMonth: _recurrence!.dayOfMonth,
          endDate: null,
        );
      }
    } else { // isEditing
      // Find the original task from provider to get the true start date (dueDate)
      // because the task passed in widget.task might be a copy from activeTasksProvider
      // which has its dueDate modified to the occurrence date.
      final allTasks = ref.read(tasksProvider);
      final originalTask = allTasks.cast<Task?>().firstWhere(
        (t) => t?.id == widget.task!.id, 
        orElse: () => widget.task
      );
      _selectedDate = originalTask?.dueDate ?? widget.task!.dueDate;
    }
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle for visual cue
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              Flexible(
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
                            (widget.task == null || widget.task?.id == null) ? 'تسک جدید' : 'ویرایش تسک',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, size: 24, color: Colors.grey),
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Title and Emoji
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showEmojiInput,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _selectedEmoji ?? '🫥',
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'چه کاری باید انجام بشه؟',
                                hintStyle: const TextStyle(fontSize: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Categories
                      const Text('دسته‌بندی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Consumer(
                        builder: (context, ref, child) {
                          final categoriesAsync = ref.watch(categoryProvider);
                          return categoriesAsync.when(
                            data: (categories) {
                              final cats = categories.isEmpty ? defaultCategories : categories;
                              return SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: cats.map((cat) {
                                  final isSelected = _selectedCategories.contains(cat.id);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedCategories.remove(cat.id);
                                        } else {
                                          _selectedCategories.add(cat.id);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? cat.color.withValues(alpha: 0.15) 
                                            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected 
                                              ? cat.color.withValues(alpha: 0.5)
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Lottie.asset(cat.emoji, width: 22, height: 22),
                                          const SizedBox(width: 8),
                                          Text(
                                            cat.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? cat.color : Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                ),
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, stack) => Text('خطا: $err'),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Collapsible Details Section
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            'جزئیات بیشتر',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          tilePadding: EdgeInsets.zero,
                          initiallyExpanded: _isDetailsExpanded,
                          onExpansionChanged: (val) {
                            setState(() => _isDetailsExpanded = val);
                          },
                          children: [
                            const SizedBox(height: 8),
                            // Date
                            ListTile(
                              onTap: () async {
                                final pickedDate = await showPersianDatePicker(
                                  context: context,
                                  initialDate: Jalali.fromDateTime(_selectedDate),
                                  firstDate: Jalali.fromDateTime(
                                    _selectedDate.isBefore(DateTime.now()) 
                                        ? _selectedDate.subtract(const Duration(days: 365)) 
                                        : DateTime.now().subtract(const Duration(days: 365))
                                  ),
                                  lastDate: Jalali.fromDateTime(DateTime.now().add(const Duration(days: 365 * 10))),
                                );
                                if (pickedDate != null) {
                                  final dt = pickedDate.toDateTime();
                                  setState(() {
                                    _selectedDate = DateTime(
                                      dt.year,
                                      dt.month,
                                      dt.day,
                                      _selectedDate.hour,
                                      _selectedDate.minute,
                                    );
                                    
                                    // If new start date is after current recurrence end date, clear end date
                                    if (_recurrence?.endDate != null && _selectedDate.isAfter(_recurrence!.endDate!)) {
                                      _recurrence = RecurrenceConfig(
                                        type: _recurrence!.type,
                                        interval: _recurrence!.interval,
                                        daysOfWeek: _recurrence!.daysOfWeek,
                                        specificDates: _recurrence!.specificDates,
                                        dayOfMonth: _recurrence!.dayOfMonth,
                                        endDate: null,
                                      );
                                    }
                                  });
                                }
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, size: 20),
                              ),
                              title: Text(
                                _recurrence != null && _recurrence!.type != RecurrenceType.none ? 'تاریخ شروع' : 'تاریخ انجام', 
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                              ),
                              subtitle: Text(
                                _formatJalali(Jalali.fromDateTime(_selectedDate)),
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              trailing: Icon(
                                Icons.chevron_right, 
                                size: 20, 
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                              ),
                            ),

                            // Time
                            ListTile(
                              onTap: () async {
                                final pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(_selectedDate),
                                  builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
                                );
                                if (pickedTime != null) {
                                  setState(() {
                                    _hasTime = true;
                                    _selectedDate = DateTime(
                                      _selectedDate.year, _selectedDate.month, _selectedDate.day,
                                      pickedTime.hour, pickedTime.minute
                                    );
                                  });
                                }
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _hasTime 
                                      ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedClock01, 
                                  size: 20,
                                  color: _hasTime ? Theme.of(context).colorScheme.secondary : Colors.grey,
                                ),
                              ),
                              title: const Text('زمان انجام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                _hasTime 
                                    ? _toPersianDigit(intl.DateFormat('HH:mm').format(_selectedDate))
                                    : 'بدون ساعت تنظیم شده',
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: _hasTime 
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : Colors.grey,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_hasTime)
                                    GestureDetector(
                                      onTap: () => setState(() => _hasTime = false),
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(25),
                                          border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                                        ),
                                        child: const Text(
                                          'حذف ساعت',
                                          style: TextStyle(
                                            color: Colors.red, 
                                            fontSize: 11, 
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Icon(
                                    Icons.chevron_right, 
                                    size: 20, 
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                                  ),
                                ],
                              ),
                            ),
                            
                            // Recurrence
                            ListTile(
                              onTap: _showRecurrencePicker,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const HugeIcon(icon: HugeIcons.strokeRoundedRepeat, size: 20, color: Colors.orange),
                              ),
                              title: const Text('تکرار', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                _getRecurrenceText(),
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              trailing: Icon(
                                Icons.chevron_right, 
                                size: 20, 
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Priority
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('اولویت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
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
                                      label: Text('عادی'),
                                      icon: HugeIcon(icon: HugeIcons.strokeRoundedMinusSign, color: Colors.grey, size: 18)
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
                                  style: SegmentedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Tags
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: TextField(
                                controller: _tagController,
                                decoration: InputDecoration(
                                  hintText: 'افزودن تگ جدید...',
                                  hintStyle: const TextStyle(fontSize: 12),
                                  prefixIcon: Container(
                                    margin: const EdgeInsetsDirectional.only(start: 14, end: 10),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedTag01, 
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 0,
                                    minHeight: 0,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedAddCircle, 
                                      size: 20
                                    ),
                                    onPressed: () {
                                      final tag = _tagController.text.trim();
                                      if (tag.isNotEmpty && !_tags.contains(tag)) {
                                        setState(() {
                                          _tags.add(tag);
                                          _tagController.clear();
                                        });
                                      }
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: (val) {
                                  final tag = val.trim();
                                  if (tag.isNotEmpty && !_tags.contains(tag)) {
                                    setState(() {
                                      _tags.add(tag);
                                      _tagController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            if (_tags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _tags.map((tag) => InputChip(
                                    label: Text(tag, style: const TextStyle(fontSize: 11)),
                                    onDeleted: () => setState(() => _tags.remove(tag)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                  )).toList(),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Description (Moved here and styled smaller)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: TextField(
                                controller: _descController,
                                maxLines: 2,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'توضیحات بیشتر...',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            
                            // Attachments
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickFile,
                                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedAttachment01, size: 18),
                                    label: const Text('پیوست فایل'),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: _toggleRecording,
                                    icon: HugeIcon(
                                      icon: _isRecording ? HugeIcons.strokeRoundedStop : HugeIcons.strokeRoundedMic01, 
                                      size: 18,
                                      color: _isRecording ? Colors.red : null,
                                    ),
                                    label: Text(_isRecording ? 'توقف ضبط' : 'ضبط صدا'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _isRecording ? Colors.red : null,
                                      side: _isRecording 
                                          ? const BorderSide(color: Colors.red) 
                                          : BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_attachments.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Wrap(
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _saveTask,
                  icon: HugeIcon(
                    icon: widget.task == null ? HugeIcons.strokeRoundedAddSquare : HugeIcons.strokeRoundedCheckmarkSquare04, 
                    size: 20, 
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  label: Text(
                    widget.task == null ? 'ثبت و شروع کار' : 'ذخیره تغییرات',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiInput() {
    final controller = TextEditingController(text: _selectedEmoji);
    if (_selectedEmoji != null) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _selectedEmoji!.length,
      );
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedSmile,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'انتخاب ایموجی',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                      ),
                    ],
                  ),
                ),
                
                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        'از کیبورد خود یک ایموجی انتخاب کنید تا جایگزین شود',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Emoji Preview/Input Circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            width: 2.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: controller,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 36),
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            hintText: '🫥',
                            hintStyle: TextStyle(fontSize: 36),
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (value) {
                            if (value.characters.isNotEmpty) {
                              final char = value.characters.last;
                              controller.text = char;
                              controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Footer Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() => _selectedEmoji = null);
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (controller.text.isNotEmpty) {
                              setState(() => _selectedEmoji = controller.text);
                            }
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('تایید', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRecurrenceText() {
    if (_recurrence == null || _recurrence!.type == RecurrenceType.none) {
      return 'بدون تکرار';
    }
    
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
    return '$typeText$endDateText';
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
                const Text('تنظیمات تکرار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
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
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('تاریخ پایان تکرار', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  subtitle: Text(_recurrence?.endDate != null 
                    ? _formatJalali(Jalali.fromDateTime(_recurrence!.endDate!))
                    : 'نامحدود',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showPersianDatePicker(
                        context: context,
                        initialDate: Jalali.fromDateTime(_recurrence?.endDate ?? _selectedDate.add(const Duration(days: 30))),
                        firstDate: Jalali.fromDateTime(_selectedDate),
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
                
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تایید'),
                  ),
                ),
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((day) {
          final dayId = day['id'] as int;
          final isSelected = _recurrence?.daysOfWeek?.contains(dayId) ?? false;
          return GestureDetector(
            onTap: () {
              setState(() {
                final currentDays = List<int>.from(_recurrence?.daysOfWeek ?? []);
                if (isSelected) {
                  currentDays.remove(dayId);
                } else {
                  currentDays.add(dayId);
                }
                _recurrence = RecurrenceConfig(
                  type: RecurrenceType.specificDays,
                  daysOfWeek: currentDays,
                  endDate: _recurrence?.endDate,
                );
              });
              setSheetState(() {});
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day['label'] as String,
                    style: TextStyle(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.onPrimary 
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecurrenceOption(RecurrenceType type, String label, StateSetter setSheetState) {
    final isSelected = (_recurrence?.type ?? RecurrenceType.none) == type;
    return InkWell(
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
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            HugeIcon(
              icon: isSelected ? HugeIcons.strokeRoundedCheckmarkCircle03 : HugeIcons.strokeRoundedCircle,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
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

  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty) return;
    
    final metadata = Map<String, dynamic>.from(widget.task?.metadata ?? {});
    metadata['hasTime'] = _hasTime;

    final task = Task(
      id: widget.task?.id,
      rootId: widget.task?.rootId,
      title: _titleController.text,
      description: _descController.text,
      dueDate: _selectedDate,
      priority: _priority,
      categories: _selectedCategories,
      category: _selectedCategories.isNotEmpty ? _selectedCategories.first : null,
      status: widget.task?.status ?? TaskStatus.pending,
      createdAt: widget.task?.createdAt,
      updatedAt: widget.task?.updatedAt,
      taskEmoji: _selectedEmoji,
      attachments: _attachments,
      tags: _tags,
      recurrence: _recurrence,
      metadata: metadata,
    );
    
    if (task.id == null) {
      await ref.read(tasksProvider.notifier).addTask(task);
    } else {
      await ref.read(tasksProvider.notifier).updateTask(task);
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
