import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
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
  String? _category;

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

  String _formatMiladiSmall(DateTime dt) {
    return intl.DateFormat('d MMM yyyy').format(dt);
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title);
    _descController = TextEditingController(text: widget.task?.description);
    _selectedDate = widget.task?.dueDate ?? DateTime.now();
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _category = widget.task?.category;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.task == null ? 'تسک جدید ✨' : 'ویرایش تسک ✏️',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'عنوان تسک چیه؟',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'توضیحات بیشتر (اختیاری)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today_rounded),
              title: const Text('زمان انجام'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatJalali(Jalali.fromDateTime(_selectedDate))),
                  Text(
                    _formatMiladiSmall(_selectedDate),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              onTap: () async {
                final picked = await showPersianDatePicker(
                  context: context,
                  initialDate: Jalali.fromDateTime(_selectedDate),
                  firstDate: Jalali.fromDateTime(DateTime.now().subtract(const Duration(days: 365))),
                  lastDate: Jalali.fromDateTime(DateTime.now().add(const Duration(days: 365))),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked.toDateTime());
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('اولویت چطوره؟', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(value: TaskPriority.low, label: Text('کم')),
                ButtonSegment(value: TaskPriority.medium, label: Text('متوسط')),
                ButtonSegment(value: TaskPriority.high, label: Text('بالا')),
              ],
              selected: {_priority},
              onSelectionChanged: (val) {
                setState(() => _priority = val.first);
              },
            ),
            const Text('دسته‌بندی چیه؟', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                'کار', 'شخصی', 'ورزش', 'مطالعه', 'خرید'
              ].map((cat) => ChoiceChip(
                label: Text(cat),
                selected: _category == cat,
                onSelected: (selected) {
                  setState(() => _category = selected ? cat : null);
                },
              )).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: () {
                  if (_titleController.text.isEmpty) return;
                  
                  final task = Task(
                    id: widget.task?.id,
                    title: _titleController.text,
                    description: _descController.text,
                    dueDate: _selectedDate,
                    priority: _priority,
                    category: _category,
                    status: widget.task?.status ?? TaskStatus.pending,
                    createdAt: widget.task?.createdAt,
                  );
                  
                  if (widget.task == null) {
                    ref.read(tasksProvider.notifier).addTask(task);
                  } else {
                    ref.read(tasksProvider.notifier).updateTask(task);
                  }
                  Navigator.pop(context);
                },
                child: Text(widget.task == null ? 'ثبت و شروع کار' : 'ذخیره تغییرات'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
