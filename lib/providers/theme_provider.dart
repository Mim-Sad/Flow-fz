import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class ThemeState {
  final Color seedColor;
  final ThemeMode themeMode;
  final bool isInitialized;

  ThemeState({
    required this.seedColor,
    required this.themeMode,
    this.isInitialized = false,
  });

  ThemeState copyWith({
    Color? seedColor,
    ThemeMode? themeMode,
    bool? isInitialized,
  }) {
    return ThemeState(
      seedColor: seedColor ?? this.seedColor,
      themeMode: themeMode ?? this.themeMode,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _seedColorKey = 'theme_seed_color';
  static const String _themeModeKey = 'theme_mode';
  late SharedPreferences _prefs;
  final _dbService = DatabaseService();

  @override
  ThemeState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    
    // Load settings synchronously from SharedPreferences
    final colorValue = _prefs.getInt(_seedColorKey);
    final modeIndex = _prefs.getInt(_themeModeKey);

    Color seedColor = const Color(0xFF6750A4);
    if (colorValue != null) {
      seedColor = Color(colorValue);
    }

    ThemeMode themeMode = ThemeMode.dark;
    if (modeIndex != null) {
      themeMode = ThemeMode.values[modeIndex];
    }
    
    // Check DB in background if needed, but return valid state immediately
    if (colorValue == null || modeIndex == null) {
       _syncWithDb();
    }

    return ThemeState(
      seedColor: seedColor,
      themeMode: themeMode,
      isInitialized: true,
    );
  }

  Future<void> _syncWithDb() async {
    // If not in SharedPreferences, try Database
    int? colorValue = _prefs.getInt(_seedColorKey);
    int? modeIndex = _prefs.getInt(_themeModeKey);
    bool changed = false;

    if (colorValue == null) {
      final dbColor = await _dbService.getSetting(_seedColorKey);
      if (dbColor != null) {
        colorValue = int.tryParse(dbColor);
        if (colorValue != null) {
          await _prefs.setInt(_seedColorKey, colorValue);
          changed = true;
        }
      }
    }

    if (modeIndex == null) {
      final dbMode = await _dbService.getSetting(_themeModeKey);
      if (dbMode != null) {
        modeIndex = int.tryParse(dbMode);
        if (modeIndex != null) {
          await _prefs.setInt(_themeModeKey, modeIndex);
          changed = true;
        }
      }
    }
    
    if (changed) {
       Color seedColor = state.seedColor;
       if (colorValue != null) {
          seedColor = Color(colorValue);
       }
       
       ThemeMode themeMode = state.themeMode;
       if (modeIndex != null) {
          themeMode = ThemeMode.values[modeIndex];
       }
       
       state = state.copyWith(
         seedColor: seedColor,
         themeMode: themeMode,
       );
    }
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    
    // Save to SharedPreferences
    await _prefs.setInt(_seedColorKey, color.toARGB32());
    
    // Save to Database
    await _dbService.setSetting(_seedColorKey, color.toARGB32().toString());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    
    // Save to SharedPreferences
    await _prefs.setInt(_themeModeKey, mode.index);
    
    // Save to Database
    await _dbService.setSetting(_themeModeKey, mode.index.toString());
  }

  static final List<Color> availableColors = [
    const Color(0xFF6750A4), // Deep Purple
    const Color(0xFF006494), // Blue
    const Color(0xFF006D3B), // Green
    const Color(0xFFBC004B), // Pink/Red
    const Color(0xFF8B5000), // Orange/Brown
    const Color(0xFF4355B9), // Indigo
    const Color(0xFF00696D), // Teal
    const Color(0xFF745B00), // Gold/Yellow
  ];
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(() {
  return ThemeNotifier();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});
