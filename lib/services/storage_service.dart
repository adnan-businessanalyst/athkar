import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/default_collections.dart';
import '../models/models.dart';

class StorageService {
  static const _countersKey = 'athkar.counters';
  static const _collectionsKey = 'athkar.collections';
  static const _locationKey = 'athkar.location';
  static const _settingsKey = 'athkar.settings';
  static const _deviceSettingsKey = 'athkar.device_settings';
  static const _deviceIdKey = 'athkar.device_id';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _store {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('StorageService.init() must be called first.');
    }
    return prefs;
  }

  List<AthkarCounter> loadCounters() {
    final raw = _store.getString(_countersKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => AthkarCounter.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCounters(List<AthkarCounter> counters) {
    return _store.setString(
      _countersKey,
      jsonEncode(counters.map((item) => item.toJson()).toList()),
    );
  }

  List<AthkarCollection> loadCollections() {
    final raw = _store.getString(_collectionsKey);
    if (raw == null || raw.isEmpty) return DefaultCollections.seed();
    final list = jsonDecode(raw) as List<dynamic>;
    final loaded = list
        .map((item) => AthkarCollection.fromJson(item as Map<String, dynamic>))
        .toList();
    return DefaultCollections.mergeMissing(loaded);
  }

  Future<void> saveCollections(List<AthkarCollection> collections) {
    return _store.setString(
      _collectionsKey,
      jsonEncode(collections.map((item) => item.toJson()).toList()),
    );
  }

  SavedLocation? loadLocation() {
    final raw = _store.getString(_locationKey);
    if (raw == null || raw.isEmpty) return null;
    return SavedLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveLocation(SavedLocation? location) {
    if (location == null) return _store.remove(_locationKey);
    return _store.setString(_locationKey, jsonEncode(location.toJson()));
  }

  AppSettings loadSettings() {
    final raw = _store.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) {
    return _store.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  bool get hasLegacyCollections {
    final raw = _store.getString(_collectionsKey);
    return raw != null && raw.isNotEmpty;
  }

  bool get hasLegacySettings {
    final raw = _store.getString(_settingsKey);
    return raw != null && raw.isNotEmpty;
  }

  AppSettings loadDeviceSettings() {
    final raw = _store.getString(_deviceSettingsKey);
    if (raw != null && raw.isNotEmpty) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings(
        adminMode: json['adminMode'] as bool? ?? false,
        adhanFilePath: json['adhanFilePath'] as String?,
      );
    }
    final legacy = loadSettings();
    return AppSettings(
      adminMode: legacy.adminMode,
      adhanFilePath: legacy.adhanFilePath,
    );
  }

  String deviceId() {
    final existing = _store.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    _store.setString(_deviceIdKey, created);
    return created;
  }

  Future<void> saveDeviceSettings({
    required bool adminMode,
    String? adhanFilePath,
  }) {
    return _store.setString(
      _deviceSettingsKey,
      jsonEncode({
        'adminMode': adminMode,
        'adhanFilePath': adhanFilePath,
      }),
    );
  }
}
