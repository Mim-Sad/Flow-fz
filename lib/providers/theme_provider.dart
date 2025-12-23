import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final Color seedColor;
  final ThemeMode themeMode;

  ThemeState({
    required this.seedColor,
    required this.themeMode,
  });

  ThemeState copyWith({
    Color? seedColor,
    ThemeMode? themeMode,
  }) {
    return ThemeState(
      seedColor: seedColor ?? this.seedColor,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _seedColorKey = 'theme_seed_color';
  static const String _themeModeKey = 'theme_mode';
  late SharedPreferences _prefs;

  @override
  ThemeState build() {
    // We return a default state first, then load from prefs asynchronously
    _initPrefs();
    
    return ThemeState(
      seedColor: const Color(0xFF6750A4), // Default color
      themeMode: ThemeMode.dark,
    );
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    final int? colorValue = _prefs.getInt(_seedColorKey);
    final int? modeIndex = _prefs.getInt(_themeModeKey);

    Color seedColor = const Color(0xFF6750A4);
    if (colorValue != null) {
      seedColor = Color(colorValue);
    }

    ThemeMode themeMode = ThemeMode.dark;
    if (modeIndex != null) {
      themeMode = ThemeMode.values[modeIndex];
    }

    state = ThemeState(
      seedColor: seedColor,
      themeMode: themeMode,
    );
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.toARGB32());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
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
