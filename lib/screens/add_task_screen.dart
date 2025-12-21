import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              leading: const Icon(Icons.calendar_today),
              title: const Text('زمان انجام'),
              subtitle: Text(
                intl.DateFormat('yyyy/MM/dd').format(_selectedDate),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
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
