import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mood_entry.dart';
import '../models/activity.dart';
import '../services/database_service.dart';

// Helper for date comparison
bool isSameDay(DateTime d1, DateTime d2) {
  return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
}

// --- Database Provider ---
// Assuming databaseServiceProvider is defined elsewhere (e.g. task_provider.dart)
// If not, we define a local helper or use the one from main/other providers.
// To avoid circular deps or redefining, I'll use a direct access or create a new one.
final moodDatabaseProvider = Provider<DatabaseService>((ref) => DatabaseService());

// --- State Classes ---

class MoodState {
  final List<MoodEntry> entries;
  final bool isLoading;
  final String? error;

  MoodState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  MoodState copyWith({
    List<MoodEntry>? entries,
    bool? isLoading,
    String? error,
  }) {
    return MoodState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ActivityState {
  final List<ActivityCategory> categories;
  final List<Activity> activities;
  final bool isLoading;

  ActivityState({
    this.categories = const [],
    this.activities = const [],
    this.isLoading = false,
  });
}

// --- Providers ---

// 1. Mood Entries Provider
final moodProvider = StateNotifierProvider<MoodNotifier, MoodState>((ref) {
  final db = ref.watch(moodDatabaseProvider);
  return MoodNotifier(db);
});

class MoodNotifier extends StateNotifier<MoodState> {
  final DatabaseService _db;

  MoodNotifier(this._db) : super(MoodState()) {
    loadMoods();
  }

  Future<void> loadMoods() async {
    // Only show loading if we don't have entries already (initial load)
    if (state.entries.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    
    try {
      final entries = await _db.getAllMoodEntries();
      state = state.copyWith(entries: entries, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> addMood(MoodEntry entry) async {
    try {
      await _db.insertMoodEntry(entry);
      await loadMoods();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateMood(MoodEntry entry) async {
    try {
      await _db.updateMoodEntry(entry);
      await loadMoods();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteMood(int id) async {
    try {
      // Optimistically remove from state for better UX
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != id).toList(),
      );

      await _db.deleteMoodEntry(id);
      // Reload from DB to be sure
      final freshEntries = await _db.getAllMoodEntries();
      state = state.copyWith(entries: freshEntries, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      // Re-load to restore state on error
      await loadMoods();
    }
  }
}

// 2. Activities Provider
final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  final db = ref.watch(moodDatabaseProvider);
  return ActivityNotifier(db);
});

class ActivityNotifier extends StateNotifier<ActivityState> {
  final DatabaseService _db;

  ActivityNotifier(this._db) : super(ActivityState()) {
    loadActivities();
  }

  Future<void> loadActivities() async {
    state = ActivityState(isLoading: true);
    try {
      final categories = await _db.getAllActivityCategories();
      final activities = await _db.getAllActivities();
      state = ActivityState(
        categories: categories,
        activities: activities,
        isLoading: false,
      );
    } catch (e) {
      state = ActivityState(isLoading: false);
    }
  }

  Future<void> addCategory(String name, {String iconName = '🗄️'}) async {
    try {
      await _db.insertActivityCategory(name, iconName);
      await loadActivities();
    } catch (_) {}
  }

  Future<void> updateCategory(ActivityCategory category) async {
    try {
      await _db.updateActivityCategory(category);
      await loadActivities();
    } catch (_) {}
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _db.deleteActivityCategory(id);
      await loadActivities();
    } catch (_) {}
  }

  Future<void> addActivity(String name, int categoryId, [String iconName = '✨']) async {
    try {
      await _db.insertActivity(name, iconName, categoryId);
      await loadActivities();
    } catch (_) {}
  }

  Future<void> deleteActivity(int id) async {
    try {
      await _db.deleteActivity(id);
      await loadActivities();
    } catch (_) {}
  }

  Future<void> updateActivity(Activity activity) async {
    try {
      await _db.updateActivity(activity);
      await loadActivities();
    } catch (_) {}
  }
}

// --- Range Provider ---
final moodsForRangeProvider = Provider.family<List<MoodEntry>, DateTimeRange>((ref, range) {
  final moodState = ref.watch(moodProvider);
  
  final startDate = DateTime(range.start.year, range.start.month, range.start.day);
   final endDate = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
 
   return moodState.entries.where((entry) {
     return entry.dateTime.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
            entry.dateTime.isBefore(endDate.add(const Duration(seconds: 1)));
   }).toList();
});
