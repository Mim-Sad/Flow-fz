import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class ThemeState {
  final Color seedColor;
  final ThemeMode themeMode;
  final bool isInitialized;
  final bool powerSavingMode;

  ThemeState({
    required this.seedColor,
    required this.themeMode,
    this.isInitialized = false,
    this.powerSavingMode = false,
  });

  ThemeState copyWith({
    Color? seedColor,
    ThemeMode? themeMode,
    bool? isInitialized,
    bool? powerSavingMode,
  }) {
    return ThemeState(
      seedColor: seedColor ?? this.seedColor,
      themeMode: themeMode ?? this.themeMode,
      isInitialized: isInitialized ?? this.isInitialized,
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _seedColorKey = 'theme_seed_color';
  static const String _themeModeKey = 'theme_mode';
  static const String _powerSavingModeKey = 'power_saving_mode';
  late SharedPreferences _prefs;
  final _dbService = DatabaseService();

  @override
  ThemeState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    
    // Load settings synchronously from SharedPreferences
    final colorValue = _prefs.getInt(_seedColorKey);
    final modeIndex = _prefs.getInt(_themeModeKey);
    final powerSavingMode = _prefs.getBool(_powerSavingModeKey) ?? false;

    Color seedColor = const Color(0xFF6750A4);
    if (colorValue != null) {
      seedColor = Color(colorValue);
    }

    ThemeMode themeMode = ThemeMode.dark;
    if (modeIndex != null) {
      themeMode = ThemeMode.values[modeIndex];
    }
    
    // Always check DB in background to ensure sync, especially after import
    _syncWithDb();

    return ThemeState(
      seedColor: seedColor,
      themeMode: themeMode,
      isInitialized: true,
      powerSavingMode: powerSavingMode,
    );
  }

  Future<void> _syncWithDb() async {
    // Check Database for settings
    final dbColor = await _dbService.getSetting(_seedColorKey);
    final dbMode = await _dbService.getSetting(_themeModeKey);
    final dbPowerSaving = await _dbService.getSetting(_powerSavingModeKey);
    
    int? colorValue = dbColor != null ? int.tryParse(dbColor) : null;
    int? modeIndex = dbMode != null ? int.tryParse(dbMode) : null;
    bool? powerSavingMode = dbPowerSaving != null ? dbPowerSaving == 'true' : null;
    
    bool changed = false;

    if (colorValue != null && colorValue != _prefs.getInt(_seedColorKey)) {
      await _prefs.setInt(_seedColorKey, colorValue);
      changed = true;
    }

    if (modeIndex != null && modeIndex != _prefs.getInt(_themeModeKey)) {
      await _prefs.setInt(_themeModeKey, modeIndex);
      changed = true;
    }

    if (powerSavingMode != null && powerSavingMode != (_prefs.getBool(_powerSavingModeKey) ?? false)) {
      await _prefs.setBool(_powerSavingModeKey, powerSavingMode);
      changed = true;
    }
    
    if (changed) {
      state = state.copyWith(
        seedColor: colorValue != null ? Color(colorValue) : state.seedColor,
        themeMode: modeIndex != null ? ThemeMode.values[modeIndex] : state.themeMode,
        powerSavingMode: powerSavingMode ?? state.powerSavingMode,
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

  Future<void> setPowerSavingMode(bool enabled) async {
    state = state.copyWith(powerSavingMode: enabled);
    
    // Save to SharedPreferences
    await _prefs.setBool(_powerSavingModeKey, enabled);
    
    // Save to Database
    await _dbService.setSetting(_powerSavingModeKey, enabled.toString());
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
