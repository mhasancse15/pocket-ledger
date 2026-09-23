import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder for app preferences (theme, currency, etc.)
class PreferencesStore {
  static final Map<String, dynamic> _prefs = {
    'isDarkMode': false,
    'currencySymbol': '৳',
    'currencyCode': 'BDT',
    'dateFormat': 'yyyy-MM-dd',
  };

  Future<bool> isDarkMode() async {
    return _prefs['isDarkMode'] as bool? ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    _prefs['isDarkMode'] = value;
  }

  Future<String> getCurrencySymbol() async {
    return _prefs['currencySymbol'] as String? ?? '৳';
  }

  Future<String> getCurrencyCode() async {
    return _prefs['currencyCode'] as String? ?? 'BDT';
  }

  Future<String> getDateFormat() async {
    return _prefs['dateFormat'] as String? ?? 'yyyy-MM-dd';
  }
}

final preferencesRepositoryProvider = Provider((ref) {
  return PreferencesStore();
});

/// Watch dark mode preference
final darkModeProvider = FutureProvider<bool>((ref) async {
  final prefs = ref.watch(preferencesRepositoryProvider);
  return prefs.isDarkMode();
});

/// Watch currency symbol preference
final currencySymbolProvider = FutureProvider<String>((ref) async {
  final prefs = ref.watch(preferencesRepositoryProvider);
  return prefs.getCurrencySymbol();
});

/// StateNotifier for preferences
class PreferencesNotifier extends StateNotifier<Map<String, dynamic>> {
  final PreferencesStore _store;

  PreferencesNotifier(this._store)
      : super({
          'isDarkMode': false,
          'currencySymbol': '৳',
        });

  Future<void> setDarkMode(bool value) async {
    await _store.setDarkMode(value);
    state = {...state, 'isDarkMode': value};
  }
}

final preferencesNotifierProvider =
    StateNotifierProvider<PreferencesNotifier, Map<String, dynamic>>((ref) {
  final store = ref.watch(preferencesRepositoryProvider);
  return PreferencesNotifier(store);
});
