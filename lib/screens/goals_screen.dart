import '../widgets/flow_toast.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../widgets/audio_waveform_player.dart';
import '../providers/tag_provider.dart';
import '../utils/string_utils.dart';
import '../models/goal.dart';
import '../models/task.dart';
import '../providers/goal_provider.dart';
import '../providers/category_provider.dart';
import '../utils/emoji_suggester.dart';
import '../widgets/lottie_category_icon.dart';
import 'dart:async';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // Emoji Suggestion
  Timer? _emojiSuggestionTimer;
  String? _lastTitleForEmoji;

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
    String weekday = j.formatter.wN;
    if (weekday == 'یک شنبه') weekday = 'یک‌شنبه';
    if (weekday == 'دو شنبه') weekday = 'دو‌شنبه';
    if (weekday == 'سه شنبه') weekday = 'سه‌شنبه';
    if (weekday == 'چهار شنبه') weekday = 'چهار‌شنبه';
    if (weekday == 'پنج شنبه') weekday = 'پنج‌شنبه';
    return _toPersianDigit('$weekday ${j.day} ${j.formatter.mN} ${j.year}');
  }

  @override
  void dispose() {
    _emojiSuggestionTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _openFile(String path) async {
    try {
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا در باز کردن فایل: $e')));
      }
    }
  }

  Future<void> _pickFiles(
    List<String> currentAttachments,
    Function(List<String>) onUpdate,
  ) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      onUpdate([...currentAttachments, result.files.single.path!]);
    }
  }

  Future<void> _toggleRecording(
    String? currentAudioPath,
    Function(String?, List<String>) onUpdate,
    List<String> currentAttachments, [
    VoidCallback? onStateChanged,
  ]) async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      onStateChanged?.call();
      if (path != null) {
        onUpdate(path, [...currentAttachments, path]);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
        onStateChanged?.call();
      }
    }
  }

  void _showGoalDialog([Goal? goal]) {
    final isEditing = goal != null;
    final titleController = TextEditingController(text: goal?.title ?? '');
    final descController = TextEditingController(text: goal?.description ?? '');
    final emojiController = TextEditingController(text: goal?.emoji ?? '🎯');
    final tagController = TextEditingController();

    String selectedEmoji = goal?.emoji ?? '🎯';
    List<String> selectedCategoryIds = List.from(goal?.categoryIds ?? []);
    DateTime? selectedDeadline = goal?.deadline;
    TaskPriority selectedPriority = goal?.priority ?? TaskPriority.medium;
    List<String> tags = List.from(goal?.tags ?? []);
    List<String> attachments = List.from(goal?.attachments ?? []);
    String? audioPath = goal?.audioPath;

    void onTitleChanged() {
      final title = titleController.text.trim();
      if (title.isEmpty) {
        _emojiSuggestionTimer?.cancel();
        return;
      }

      bool shouldSuggest = false;
      if (selectedEmoji == '🎯') {
        shouldSuggest = true;
      } else if (_lastTitleForEmoji != null && _lastTitleForEmoji != title) {
        shouldSuggest = true;
      }

      if (shouldSuggest) {
        _emojiSuggestionTimer?.cancel();
        _emojiSuggestionTimer = Timer(const Duration(milliseconds: 600), () {
          final currentTitle = titleController.text.trim();
          if (currentTitle.isNotEmpty && mounted) {
            final suggestedEmoji = EmojiSuggester.suggestEmoji(currentTitle);
            if (suggestedEmoji != null) {
              emojiController.text = suggestedEmoji;
              selectedEmoji = suggestedEmoji;
              _lastTitleForEmoji = currentTitle;
            }
          }
        });
      }
    }

    titleController.addListener(onTitleChanged);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final categoriesAsync = ref.watch(categoryProvider);

          void addTag(String tag) {
            final trimmedTag = tag.trim();
            if (trimmedTag.isNotEmpty &&
                !StringUtils.containsTag(tags, trimmedTag)) {
              setModalState(() {
                tags.add(trimmedTag);
                tagController.clear();
              });
            } else if (trimmedTag.isNotEmpty) {
              tagController.clear();
              FlowToast.show(
                context,
                message: 'این تگ قبلاً اضافه شده است',
                type: FlowToastType.warning,
              );
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pull handle
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedTarget02,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    isEditing ? 'ویرایش هدف' : 'هدف جدید',
                                    style: Theme.of(context).textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCancel01,
                                      size: 22,
                                      color: Colors.grey,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    style: const ButtonStyle(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                          const SizedBox(height: 24),

                          // Emoji & Title
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: TextField(
                                  controller: emojiController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 26),
                                  keyboardType: TextInputType.text,
                                  decoration: const InputDecoration(
                                    hintText: '🎯',
                                    hintStyle: TextStyle(fontSize: 26),
                                    counterText: '',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      if (value.characters.isNotEmpty) {
                                        final char = value.characters.last;
                                        emojiController.text = char;
                                        emojiController.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset:
                                                    emojiController.text.length,
                                              ),
                                            );
                                        selectedEmoji = char;
                                      } else {
                                        selectedEmoji = '🎯';
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: titleController,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'عنوان هدف',
                                    hintStyle: const TextStyle(fontSize: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Description (under Title)
                          TextField(
                            controller: descController,
                            maxLines: 3,
                            minLines: 1,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'توضیحات هدف...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Categories
                          categoriesAsync.when(
                            data: (categories) {
                              if (categories.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: categories.map((cat) {
                                        final isSelected = selectedCategoryIds
                                            .contains(cat.id);
                                        return GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              if (isSelected) {
                                                selectedCategoryIds.remove(
                                                  cat.id,
                                                );
                                              } else {
                                                selectedCategoryIds.add(cat.id);
                                              }
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? cat.color.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected
                                                    ? cat.color.withValues(
                                                        alpha: 0.5,
                                                      )
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                LottieCategoryIcon(
                                                  assetPath: cat.emoji,
                                                  width: 22,
                                                  height: 22,
                                                  repeat: false,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  cat.label,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    color: isSelected
                                                        ? cat.color
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 20),

                          // Deadline
                          ListTile(
                            onTap: () async {
                              final pickedDate = await showPersianDatePicker(
                                context: context,
                                initialDate: selectedDeadline != null
                                    ? Jalali.fromDateTime(selectedDeadline!)
                                    : Jalali.now(),
                                firstDate: Jalali.now(),
                                lastDate: Jalali.now().addYears(10),
                              );
                              if (pickedDate != null) {
                                final dt = pickedDate.toDateTime();
                                setModalState(() => selectedDeadline = dt);
                              }
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCalendar03,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'تاریخ رسیدن به هدف',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              selectedDeadline != null
                                  ? _formatJalali(
                                      Jalali.fromDateTime(selectedDeadline!),
                                    )
                                  : 'تاریخی انتخاب نشده',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Priority
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<TaskPriority>(
                                segments: const [
                                  ButtonSegment(
                                    value: TaskPriority.low,
                                    label: Text('فرعی'),
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedArrowDown01,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: TaskPriority.medium,
                                    label: Text('عادی'),
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedMinusSign,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: TaskPriority.high,
                                    label: Text('فوری'),
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedAlertCircle,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                ],
                                selected: {selectedPriority},
                                onSelectionChanged: (val) {
                                    setModalState(() => selectedPriority = val.first);
                                  },
                                style: SegmentedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tags
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: TextField(
                              controller: tagController,
                              onChanged: (value) => setModalState(() {}),
                              decoration: InputDecoration(
                                hintText: 'افزودن تگ جدید...',
                                hintStyle: const TextStyle(fontSize: 12),
                                prefixIcon: Container(
                                  margin: const EdgeInsetsDirectional.only(
                                    start: 14,
                                    end: 10,
                                  ),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedTag01,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0,
                                  minHeight: 0,
                                ),
                                suffixIcon: IconButton(
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedAddCircle,
                                    size: 20,
                                  ),
                                  onPressed: () => addTag(tagController.text),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (val) => addTag(val),
                            ),
                          ),

                          // Suggestions (Centered and padded like main tags) - Shown first while typing
                          if (tagController.text.isNotEmpty) ...[
                            Consumer(
                              builder: (context, ref, child) {
                                final suggestions = ref.watch(
                                  tagSuggestionsProvider(tagController.text),
                                );
                                final filteredSuggestions = suggestions
                                    .where(
                                      (s) => !StringUtils.containsTag(tags, s),
                                    )
                                    .take(5)
                                    .toList();

                                if (filteredSuggestions.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    0,
                                  ),
                                  child: Center(
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: filteredSuggestions
                                          .map(
                                            (suggestion) => ActionChip(
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    suggestion,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.add,
                                                    size: 14,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  ),
                                                ],
                                              ),
                                              onPressed: () =>
                                                  addTag(suggestion),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                                  .withValues(alpha: 0.3),
                                              side: BorderSide(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.2),
                                              ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 0,
                                                  ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          // Added Tags (Centered and padded)
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: tags
                                      .map(
                                        (tag) => ActionChip(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                tag,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.close,
                                                size: 14,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                              ),
                                            ],
                                          ),
                                          onPressed: () => setModalState(
                                            () => tags.remove(tag),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer
                                              .withValues(alpha: 0.3),
                                          side: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withValues(alpha: 0.2),
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 0,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          const SizedBox(height: 20),

                          // Attachments
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _pickFiles(attachments, (
                                  newAtts,
                                ) {
                                  setModalState(() => attachments = newAtts);
                                }),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await _toggleRecording(
                                    audioPath,
                                    (path, newAtts) {
                                      setModalState(() {
                                        audioPath = path;
                                        attachments = newAtts;
                                      });
                                    },
                                    attachments,
                                    () => setModalState(() {}),
                                  );
                                },
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
                                  foregroundColor: _isRecording
                                      ? Colors.red
                                      : null,
                                  side: _isRecording
                                      ? const BorderSide(color: Colors.red)
                                      : BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (attachments.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                children: attachments.map((att) {
                                  final name = att.split('/').last;
                                  final isVoice =
                                      name.startsWith('voice_') ||
                                      att.endsWith('.m4a');
                                  final isImage =
                                      name.toLowerCase().endsWith('.jpg') ||
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
                                          setModalState(() {
                                            attachments.remove(att);
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
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outlineVariant
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              HugeIcon(
                                                icon: isImage
                                                    ? HugeIcons
                                                          .strokeRoundedImage01
                                                    : HugeIcons
                                                          .strokeRoundedFile01,
                                                size: 18,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  name.length > 30
                                                      ? '${name.substring(0, 30)}...'
                                                      : name,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  setModalState(() {
                                                    attachments.remove(att);
                                                  });
                                                },
                                                child: HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedCancel01,
                                                  size: 18,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
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
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    // Action Button (Sticky bottom with fade)
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
                                Theme.of(context).colorScheme.surface,
                                Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: 0.8),
                                Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: 0),
                              ],
                              stops: const [0, 0.6, 1.0],
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: () {
                                if (titleController.text.trim().isEmpty) {
                                  FlowToast.show(
                                    context,
                                    message: 'لطفاً عنوان هدف را وارد کنید',
                                    type: FlowToastType.warning,
                                  );
                                  return;
                                }
                                final newGoal = Goal(
                                  id: goal?.id,
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  emoji: selectedEmoji,
                                  categoryIds: selectedCategoryIds,
                                  deadline: selectedDeadline,
                                  priority: selectedPriority,
                                  tags: tags,
                                  attachments: attachments,
                                  audioPath: audioPath,
                                  createdAt: goal?.createdAt ?? DateTime.now(),
                                  updatedAt: DateTime.now(),
                                  position: goal?.position ?? 0,
                                );
                                if (isEditing) {
                                  ref
                                      .read(goalsProvider.notifier)
                                      .updateGoal(newGoal);
                                } else {
                                  ref.read(goalsProvider.notifier).addGoal(newGoal);
                                }
                                Navigator.pop(context);
                              },
                              icon: HugeIcon(
                                icon: isEditing
                                    ? HugeIcons.strokeRoundedTarget03
                                    : HugeIcons.strokeRoundedTarget03,
                                size: 20,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              label: Text(
                                isEditing ? 'بروزرسانی هدف' : 'ثبت هدف',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
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
          ),
        );
      },
      ),
    ).then((_) => titleController.removeListener(onTitleChanged));
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final theme = Theme.of(context);

    final navigationBarColor = theme.brightness == Brightness.light
        ? ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          )
        : ElevationOverlay.applySurfaceTint(
            theme.colorScheme.surface,
            theme.colorScheme.surfaceTint,
            3,
          );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        backgroundColor: navigationBarColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'مدیریت اهداف',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => _showGoalDialog(),
          ),
        ],
      ),
      body: goals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedTarget02,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'هنوز هدفی تعریف نکرده‌اید',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final items = List<Goal>.from(goals);
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                ref.read(goalsProvider.notifier).reorderGoals(items);
              },
              itemBuilder: (context, index) {
                final goal = goals[index];
                final progress = ref.watch(goalProgressProvider(GoalProgressArgs(goalId: goal.id!))) ?? 0.0;

                return Container(
                  key: ValueKey(goal.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            goal.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        title: Text(
                          goal.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle:
                            (goal.description != null &&
                                goal.description!.isNotEmpty)
                            ? Text(
                                goal.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedEdit02,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () => _showGoalDialog(goal),
                            ),
                            IconButton(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedDelete02,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('حذف هدف'),
                                    content: Text(
                                      'آیا از حذف "${goal.title}" مطمئن هستید؟',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('خیر'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(goalsProvider.notifier)
                                              .deleteGoal(goal.id!);
                                          Navigator.pop(context);
                                        },
                                        child: const Text('بله'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            ReorderableDragStartListener(
                              index: index,
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedMove,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'پیشرفت',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${progress.toInt()}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Full width bar at bottom
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          minHeight: 10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
