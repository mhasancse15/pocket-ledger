import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/preferences_provider.dart';

/// ViewModel for app settings management
class SettingsViewModel {
  final Ref _ref;

  SettingsViewModel(this._ref);

  /// Toggle dark mode
  Future<void> toggleDarkMode(bool isDark) async {
    await _ref.read(preferencesNotifierProvider.notifier).setDarkMode(isDark);
  }

  /// Get current dark mode setting
  bool isDarkMode() {
    final prefs = _ref.read(preferencesNotifierProvider);
    return prefs['isDarkMode'] as bool? ?? false;
  }

  /// Get app version
  String getAppVersion() {
    return '1.0.0';
  }

  /// Get app name
  String getAppName() {
    return 'Pocket Ledger';
  }

  /// Export data as CSV
  Future<String> exportDataAsCSV() async {
    // Placeholder - to be implemented in Phase 2
    return 'CSV export not yet implemented';
  }

  /// Export data as PDF
  Future<String> exportDataAsPDF() async {
    // Placeholder - to be implemented in Phase 2
    return 'PDF export not yet implemented';
  }

  /// Backup data
  Future<void> backupData() async {
    // Placeholder - to be implemented in Phase 2
  }

  /// Restore data
  Future<void> restoreData(String backupPath) async {
    // Placeholder - to be implemented in Phase 2
  }

  /// Clear all data
  Future<void> clearAllData() async {
    // Placeholder - to be implemented in Phase 2
  }
}

/// Provider for SettingsViewModel
final settingsViewModelProvider = Provider((ref) {
  return SettingsViewModel(ref);
});
