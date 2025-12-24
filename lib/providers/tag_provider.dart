import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task_provider.dart';
import '../utils/string_utils.dart';

/// Provider that returns all unique tags from all existing tasks
final allTagsProvider = Provider<List<String>>((ref) {
  final tasks = ref.watch(tasksProvider);
  
  final Set<String> uniqueTags = {};
  final Set<String> normalizedTags = {};

  for (final task in tasks) {
    for (final tag in task.tags) {
      final normalized = StringUtils.normalize(tag);
      if (!normalizedTags.contains(normalized)) {
        normalizedTags.add(normalized);
        uniqueTags.add(tag);
      }
    }
  }

  return uniqueTags.toList()..sort();
});

/// Provider for filtered tag suggestions based on current input
final tagSuggestionsProvider = Provider.family<List<String>, String>((ref, query) {
  if (query.isEmpty) return [];
  
  final allTags = ref.watch(allTagsProvider);
  final normalizedQuery = StringUtils.normalize(query);
  
  return allTags.where((tag) {
    final normalizedTag = StringUtils.normalize(tag);
    return normalizedTag.contains(normalizedQuery);
  }).toList();
});
