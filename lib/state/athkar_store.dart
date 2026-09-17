import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../services/local_file.dart' if (dart.library.io) '../services/local_file_io.dart';

import '../data/cities.dart';
import '../data/local/database.dart';
import '../models/models.dart';
import '../services/adhan_player.dart';
import '../services/api_client.dart';
import '../services/local_repository.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_times_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/token_store.dart';

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

class AthkarStore extends ChangeNotifier with WidgetsBindingObserver {
  AthkarStore({
    StorageService? storage,
    PrayerTimesService? prayerTimes,
    LocationService? location,
    NotificationService? notifications,
    AdhanPlayer? player,
    AppDatabase? database,
    DateTime Function()? clock,
    TokenStore? tokenStore,
    ApiClient? api,
    this.enableForegroundAdhanWatch = true,
    this.enableCloudSync = true,
  }) : _storage = storage ?? StorageService(),
       _prayerTimes = prayerTimes ?? PrayerTimesService(),
       _location = location ?? LocationService(),
       _notifications = notifications ?? NotificationService(),
       _player = player ?? AdhanPlayer(),
       _providedDb = database,
       _clock = clock ?? DateTime.now,
       _tokens = tokenStore ??
           (enableCloudSync ? SecureTokenStore() : MemoryTokenStore()),
       _providedApi = api;

  final bool enableForegroundAdhanWatch;
  final bool enableCloudSync;

  final StorageService _storage;
  final PrayerTimesService _prayerTimes;
  final LocationService _location;
  final NotificationService _notifications;
  final AdhanPlayer _player;
  final AppDatabase? _providedDb;
  final DateTime Function() _clock;
  final _uuid = const Uuid();
  late final AppDatabase _db;
  late final LocalRepository _repo;
  late final ApiClient _api;
  late final SyncService _sync;
  final TokenStore _tokens;
  final ApiClient? _providedApi;

  List<AthkarCounter> counters = [];
  List<AthkarCollection> collections = [];
  SavedLocation? location;
  AppSettings settings = const AppSettings();
  DailyPrayers? today;
  DailyPrayers? tomorrow;
  Map<String, int> streaks = {};
  String? error;
  bool loadingLocation = false;
  String? lastPlayedPrayerKey;
  String? accountEmail;
  DateTime? lastSyncedAt;
  bool syncInProgress = false;
  bool pendingSync = false;
  Timer? _ticker;
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  DateTime get _today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> init() async {
    await _storage.init();
    _db = _providedDb ?? AppDatabase();
    _repo = LocalRepository(_db, clock: _clock);
    await _repo.migrateFromPrefsIfNeeded(_storage);
    await _repo.ensureDefaults();
    await _repo.rolloverIfNeeded();
    counters = await _repo.loadCounters();
    collections = await _repo.loadCollections();
    location = await _repo.loadLocation();
    final synced = await _repo.loadSettings();
    final device = _storage.loadDeviceSettings();
    settings = synced.copyWith(
      adminMode: false,
      adhanFilePath: device.adhanFilePath,
    );
    _api = _providedApi ?? ApiClient(tokens: _tokens);
    _sync = SyncService(_api, _repo);
    accountEmail = await _tokens.readEmail();
    await _refreshStreaks();
    await _notifications.init();
    refreshPrayerTimes();
    await _syncSchedules();
    if (enableForegroundAdhanWatch) {
      _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
        _maybePlayAdhan();
      });
    }
    if (enableCloudSync) {
      WidgetsBinding.instance.addObserver(this);
      _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        unawaited(syncNow());
      });
      _connectivity = Connectivity().onConnectivityChanged.listen((results) {
        if (results.any((item) => item != ConnectivityResult.none)) {
          unawaited(syncNow());
        }
      });
      unawaited(syncNow());
    }
    notifyListeners();
  }

  bool get isLoggedIn => accountEmail != null && accountEmail!.isNotEmpty;

  String get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return 'unknown';
    }
  }

  Future<void> _refreshStreaks() async {
    final next = <String, int>{};
    for (final collection in collections) {
      next[collection.id] = await _repo.streakFor(collection.id);
    }
    streaks = next;
  }

  Future<void> _reloadFromDb() async {
    counters = await _repo.loadCounters();
    collections = await _repo.loadCollections();
    location = await _repo.loadLocation();
    final synced = await _repo.loadSettings();
    settings = synced.copyWith(
      adminMode: false,
      adhanFilePath: settings.adhanFilePath,
    );
    pendingSync = isLoggedIn && await _repo.hasDirty();
    await _refreshStreaks();
    refreshPrayerTimes();
    await _syncSchedules();
  }

  Future<void> _saveAuth(Map<String, dynamic> data) async {
    final user = data['user'] as Map<String, dynamic>?;
    await _tokens.save(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
      email: user?['email'] as String? ?? '',
    );
    accountEmail = user?['email'] as String?;
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final data = await _api.post('/auth/register', {
      'email': email.trim(),
      'password': password,
      'display_name': displayName?.trim().isEmpty == true
          ? null
          : displayName?.trim(),
      'device_id': _storage.deviceId(),
      'platform': _platformName,
    });
    await _saveAuth(data);
    await syncNow(forceFull: true);
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final data = await _api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
      'device_id': _storage.deviceId(),
      'platform': _platformName,
    });
    await _saveAuth(data);
    await syncNow(forceFull: true);
    notifyListeners();
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefresh();
    try {
      if (refresh != null) {
        await _api.post('/auth/logout', {'refresh_token': refresh}, auth: true);
      }
    } catch (_) {}
    await _tokens.clear();
    accountEmail = null;
    pendingSync = false;
    lastSyncedAt = null;
    notifyListeners();
  }

  Future<void> deleteRemoteAccount() async {
    await _api.delete('/account');
    await _tokens.clear();
    accountEmail = null;
    pendingSync = false;
    lastSyncedAt = null;
    notifyListeners();
  }

  Future<void> syncNow({bool forceFull = false}) async {
    if (!enableCloudSync || !isLoggedIn || syncInProgress) return;
    syncInProgress = true;
    notifyListeners();
    try {
      await _sync.push(includeAll: forceFull || await _repo.serverRevision() == 0);
      await _reloadFromDb();
      lastSyncedAt = _clock();
      error = null;
    } catch (err) {
      pendingSync = true;
      error = err.toString();
    } finally {
      syncInProgress = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(syncNow());
    }
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
      location = (await _location.detect()).copyWith(updatedAt: _clock());
      await _repo.saveLocation(location!);
      pendingSync = isLoggedIn;
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
      updatedAt: _clock(),
    );
    error = null;
    await _repo.saveLocation(location!);
    pendingSync = isLoggedIn;
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
      updatedAt: _clock(),
    );
    error = null;
    await _repo.saveLocation(location!);
    pendingSync = isLoggedIn;
    refreshPrayerTimes();
    await _syncSchedules();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next.copyWith(updatedAt: _clock(), adminMode: false);
    await _repo.saveSettings(settings);
    pendingSync = isLoggedIn;
    await _storage.saveDeviceSettings(
      adminMode: settings.adminMode,
      adhanFilePath: settings.adhanFilePath,
    );
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
    await _repo.saveCounters(counters);
    pendingSync = isLoggedIn;
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
    await _repo.saveCounters(counters);
    pendingSync = isLoggedIn;
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
    await _repo.saveCounters(counters);
    pendingSync = isLoggedIn;
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
    await _repo.saveCounters(counters);
    pendingSync = isLoggedIn;
    notifyListeners();
  }

  Future<void> deleteCounter(String id) async {
    counters = counters.where((counter) => counter.id != id).toList();
    await _repo.saveCounters(counters);
    pendingSync = isLoggedIn;
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
        if (item.id == collection.id)
          collection.copyWith(updatedAt: collection.updatedAt ?? _clock())
        else
          item,
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
        updatedAt: _clock(),
        items: [
          for (final item in collection.items)
            if (item.id == itemId && !item.isDone)
              item.copyWith(progress: item.progress + 1, updatedAt: _clock())
            else
              item,
        ],
      ),
    );
    final next = collectionById(collectionId);
    if (next != null &&
        next.items.isNotEmpty &&
        next.items.every((item) => item.isDone)) {
      await _repo.upsertDailyProgress(next, date: _today);
    }
    await _refreshStreaks();
  }

  Future<void> resetCollectionProgress(String collectionId) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    await updateCollection(
      collection.copyWith(
        updatedAt: _clock(),
        items: [
          for (final item in collection.items)
            item.copyWith(progress: 0, updatedAt: _clock()),
        ],
      ),
    );
    final next = collectionById(collectionId);
    if (next != null) {
      await _repo.upsertDailyProgress(next, date: _today, completed: false);
    }
    await _refreshStreaks();
  }

  Future<int> streakFor(String collectionId) {
    return _repo.streakFor(collectionId);
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
    await _repo.saveCollections(collections);
    pendingSync = isLoggedIn;
    await _notifications.rescheduleAthkarReminders(collections);
    notifyListeners();
  }

  List<CityOption> get cities => knownCities;

  @override
  void dispose() {
    _ticker?.cancel();
    _syncTimer?.cancel();
    unawaited(_connectivity?.cancel() ?? Future.value());
    if (enableCloudSync) {
      WidgetsBinding.instance.removeObserver(this);
    }
    unawaited(_player.dispose());
    if (_providedDb == null) {
      unawaited(_db.close());
    }
    super.dispose();
  }
}
