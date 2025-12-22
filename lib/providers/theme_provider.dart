import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  ThemeState build() {
    return ThemeState(
      seedColor: const Color(0xFF6750A4), // Default color
      themeMode: ThemeMode.dark,
    );
  }

  void setSeedColor(Color color) {
    state = state.copyWith(seedColor: color);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
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
