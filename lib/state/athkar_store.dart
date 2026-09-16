import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../services/local_file.dart' if (dart.library.io) '../services/local_file_io.dart';

import '../data/cities.dart';
import '../models/models.dart';
import '../services/adhan_player.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_times_service.dart';
import '../services/storage_service.dart';

class StoreScope extends InheritedNotifier<AthkarStore> {
  const StoreScope({
    super.key,
    required AthkarStore store,
    required super.child,
  }) : super(notifier: store);

  static AthkarStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}

class AthkarStore extends ChangeNotifier {
  AthkarStore({
    StorageService? storage,
    PrayerTimesService? prayerTimes,
    LocationService? location,
    NotificationService? notifications,
    AdhanPlayer? player,
    this.enableForegroundAdhanWatch = true,
  }) : _storage = storage ?? StorageService(),
       _prayerTimes = prayerTimes ?? PrayerTimesService(),
       _location = location ?? LocationService(),
       _notifications = notifications ?? NotificationService(),
       _player = player ?? AdhanPlayer();

  final bool enableForegroundAdhanWatch;

  final StorageService _storage;
  final PrayerTimesService _prayerTimes;
  final LocationService _location;
  final NotificationService _notifications;
  final AdhanPlayer _player;
  final _uuid = const Uuid();

  List<AthkarCounter> counters = [];
  List<AthkarCollection> collections = [];
  SavedLocation? location;
  AppSettings settings = const AppSettings();
  DailyPrayers? today;
  DailyPrayers? tomorrow;
  String? error;
  bool loadingLocation = false;
  String? lastPlayedPrayerKey;
  Timer? _ticker;

  Future<void> init() async {
    await _storage.init();
    counters = _storage.loadCounters();
    collections = _storage.loadCollections();
    location = _storage.loadLocation();
    settings = _storage.loadSettings();
    await _notifications.init();
    refreshPrayerTimes();
    await _syncSchedules();
    if (enableForegroundAdhanWatch) {
      _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
        _maybePlayAdhan();
      });
    }
    notifyListeners();
  }

  void refreshPrayerTimes() {
    final current = location;
    if (current == null) {
      today = null;
      tomorrow = null;
      return;
    }
    today = _prayerTimes.calculate(
      location: current,
      method: settings.calculationMethod,
      madhab: settings.madhab,
    );
    tomorrow = _prayerTimes.calculate(
      location: current,
      method: settings.calculationMethod,
      madhab: settings.madhab,
      date: DateTime.now().add(const Duration(days: 1)),
    );
  }

  Future<void> _syncSchedules() async {
    if (today != null && tomorrow != null) {
      await _notifications.reschedulePrayers(
        today: today!,
        tomorrow: tomorrow!,
        settings: settings,
      );
    }
    await _notifications.rescheduleAthkarReminders(collections);
  }

  Future<void> detectLocation() async {
    loadingLocation = true;
    error = null;
    notifyListeners();
    try {
      location = await _location.detect();
      await _storage.saveLocation(location);
      refreshPrayerTimes();
      await _syncSchedules();
    } catch (err) {
      error = err.toString();
    } finally {
      loadingLocation = false;
      notifyListeners();
    }
  }

  Future<void> selectCity(CityOption city) async {
    location = SavedLocation(
      latitude: city.latitude,
      longitude: city.longitude,
      label: city.label,
      source: LocationSource.city,
      city: city.name,
      country: city.country,
    );
    error = null;
    await _storage.saveLocation(location);
    refreshPrayerTimes();
    await _syncSchedules();
    notifyListeners();
  }

  Future<void> setCustomLocation({
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    location = SavedLocation(
      latitude: latitude,
      longitude: longitude,
      label: label,
      source: LocationSource.custom,
    );
    error = null;
    await _storage.saveLocation(location);
    refreshPrayerTimes();
    await _syncSchedules();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await _storage.saveSettings(settings);
    refreshPrayerTimes();
    await _syncSchedules();
    notifyListeners();
  }

  Future<void> importAdhanFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'ogg', 'aac'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final dest = await copyToDocuments(path);
      if (dest == null) {
        error = 'استيراد ملف الأذان غير متاح على هذا الجهاز.';
        notifyListeners();
        return;
      }
      await updateSettings(settings.copyWith(adhanFilePath: dest));
    } catch (err) {
      error = 'تعذر حفظ ملف الأذان: $err';
      notifyListeners();
    }
  }

  Future<bool> hasAdhanAudio() {
    return _player.hasAudio(importedPath: settings.adhanFilePath);
  }

  Future<void> testAdhan() {
    return _player.play(importedPath: settings.adhanFilePath);
  }

  Future<void> stopAdhan() => _player.stop();

  void _maybePlayAdhan() {
    final prayers = today;
    if (prayers == null || !settings.adhanEnabled) return;
    final now = DateTime.now();
    for (final slot in prayers.salahSlots) {
      if (!settings.isAdhanOn(slot.id)) continue;
      final diff = now.difference(slot.time).inSeconds.abs();
      if (diff > 45) continue;
      final key =
          '${prayers.date.toIso8601String().split('T').first}-${slot.id}';
      if (lastPlayedPrayerKey == key) return;
      lastPlayedPrayerKey = key;
      unawaited(_player.play(importedPath: settings.adhanFilePath));
      notifyListeners();
      return;
    }
  }

  Future<void> addCounter(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    counters = [
      ...counters,
      AthkarCounter(
        id: _uuid.v4(),
        name: trimmed,
        count: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await _storage.saveCounters(counters);
    notifyListeners();
  }

  Future<void> incrementCounter(String id) async {
    counters = [
      for (final counter in counters)
        if (counter.id == id)
          counter.copyWith(
            count: counter.count + 1,
            updatedAt: DateTime.now(),
          )
        else
          counter,
    ];
    await _storage.saveCounters(counters);
    notifyListeners();
  }

  Future<void> resetCounter(String id) async {
    counters = [
      for (final counter in counters)
        if (counter.id == id)
          counter.copyWith(count: 0, updatedAt: DateTime.now())
        else
          counter,
    ];
    await _storage.saveCounters(counters);
    notifyListeners();
  }

  Future<void> renameCounter(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    counters = [
      for (final counter in counters)
        if (counter.id == id)
          counter.copyWith(name: trimmed, updatedAt: DateTime.now())
        else
          counter,
    ];
    await _storage.saveCounters(counters);
    notifyListeners();
  }

  Future<void> deleteCounter(String id) async {
    counters = counters.where((counter) => counter.id != id).toList();
    await _storage.saveCounters(counters);
    notifyListeners();
  }

  AthkarCounter? counterById(String id) {
    for (final counter in counters) {
      if (counter.id == id) return counter;
    }
    return null;
  }

  AthkarCollection? collectionById(String id) {
    for (final collection in collections) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  Future<void> addCollection({
    required String name,
    String description = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    collections = [
      ...collections,
      AthkarCollection(
        id: _uuid.v4(),
        name: trimmed,
        description: description.trim(),
        isDefault: false,
      ),
    ];
    await _persistCollections();
  }

  Future<void> updateCollection(AthkarCollection collection) async {
    collections = [
      for (final item in collections)
        if (item.id == collection.id) collection else item,
    ];
    await _persistCollections();
  }

  Future<void> deleteCollection(String id) async {
    final collection = collectionById(id);
    if (collection == null || collection.isDefault) return;
    collections = collections.where((item) => item.id != id).toList();
    await _persistCollections();
  }

  Future<void> addItem({
    required String collectionId,
    required String text,
    int repeatCount = 1,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final collection = collectionById(collectionId);
    if (collection == null) return;
    await updateCollection(
      collection.copyWith(
        items: [
          ...collection.items,
          AthkarItem(
            id: _uuid.v4(),
            text: trimmed,
            repeatCount: repeatCount < 1 ? 1 : repeatCount,
          ),
        ],
      ),
    );
  }

  Future<void> updateItem(String collectionId, AthkarItem item) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    await updateCollection(
      collection.copyWith(
        items: [
          for (final current in collection.items)
            if (current.id == item.id) item else current,
        ],
      ),
    );
  }

  Future<void> deleteItem(String collectionId, String itemId) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    await updateCollection(
      collection.copyWith(
        items: collection.items.where((item) => item.id != itemId).toList(),
      ),
    );
  }

  Future<void> tickItem(String collectionId, String itemId) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    await updateCollection(
      collection.copyWith(
        items: [
          for (final item in collection.items)
            if (item.id == itemId && !item.isDone)
              item.copyWith(progress: item.progress + 1)
            else
              item,
        ],
      ),
    );
  }

  Future<void> resetCollectionProgress(String collectionId) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    await updateCollection(
      collection.copyWith(
        items: [
          for (final item in collection.items) item.copyWith(progress: 0),
        ],
      ),
    );
  }

  Future<void> setReminder(String collectionId, AthkarReminder reminder) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    await updateCollection(collection.copyWith(reminder: reminder));
  }

  Future<void> toggleFavorite(String collectionId) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    await updateCollection(
      collection.copyWith(isFavorite: !collection.isFavorite),
    );
  }

  Future<void> _persistCollections() async {
    await _storage.saveCollections(collections);
    await _notifications.rescheduleAthkarReminders(collections);
    notifyListeners();
  }

  List<CityOption> get cities => knownCities;

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }
}
