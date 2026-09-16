enum LocationSource { gps, city, custom }

class SavedLocation {
  const SavedLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.source,
    this.city,
    this.country,
  });

  final double latitude;
  final double longitude;
  final String label;
  final LocationSource source;
  final String? city;
  final String? country;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'label': label,
    'source': source.name,
    'city': city,
    'country': country,
  };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      label: json['label'] as String? ?? 'موقع محفوظ',
      source: LocationSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => LocationSource.custom,
      ),
      city: json['city'] as String?,
      country: json['country'] as String?,
    );
  }
}

class PrayerSlot {
  const PrayerSlot({
    required this.id,
    required this.arabicName,
    required this.time,
    this.isSunrise = false,
  });

  final String id;
  final String arabicName;
  final DateTime time;
  final bool isSunrise;
}

class DailyPrayers {
  const DailyPrayers({required this.date, required this.slots});

  final DateTime date;
  final List<PrayerSlot> slots;

  List<PrayerSlot> get salahSlots =>
      slots.where((slot) => !slot.isSunrise).toList();

  PrayerSlot? get nextSalah {
    final now = DateTime.now();
    for (final slot in salahSlots) {
      if (slot.time.isAfter(now)) return slot;
    }
    return null;
  }

  PrayerSlot? get currentOrNext => nextSalah ?? salahSlots.firstOrNull;
}

class AthkarCounter {
  const AthkarCounter({
    required this.id,
    required this.name,
    required this.count,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int count;
  final DateTime createdAt;
  final DateTime updatedAt;

  AthkarCounter copyWith({String? name, int? count, DateTime? updatedAt}) {
    return AthkarCounter(
      id: id,
      name: name ?? this.name,
      count: count ?? this.count,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'count': count,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AthkarCounter.fromJson(Map<String, dynamic> json) {
    return AthkarCounter(
      id: json['id'] as String,
      name: json['name'] as String,
      count: json['count'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class AthkarReminder {
  const AthkarReminder({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  AthkarReminder copyWith({bool? enabled, int? hour, int? minute}) {
    return AthkarReminder(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
  };

  factory AthkarReminder.fromJson(Map<String, dynamic> json) {
    return AthkarReminder(
      enabled: json['enabled'] as bool? ?? false,
      hour: json['hour'] as int? ?? 6,
      minute: json['minute'] as int? ?? 0,
    );
  }
}

class AthkarItem {
  const AthkarItem({
    required this.id,
    required this.text,
    required this.repeatCount,
    this.progress = 0,
  });

  final String id;
  final String text;
  final int repeatCount;
  final int progress;

  bool get isDone => progress >= repeatCount;

  AthkarItem copyWith({String? text, int? repeatCount, int? progress}) {
    return AthkarItem(
      id: id,
      text: text ?? this.text,
      repeatCount: repeatCount ?? this.repeatCount,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'repeatCount': repeatCount,
    'progress': progress,
  };

  factory AthkarItem.fromJson(Map<String, dynamic> json) {
    return AthkarItem(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      repeatCount: json['repeatCount'] as int? ?? 1,
      progress: json['progress'] as int? ?? 0,
    );
  }
}

class AthkarCollection {
  const AthkarCollection({
    required this.id,
    required this.name,
    required this.isDefault,
    this.description = '',
    this.items = const [],
    this.reminder,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String description;
  final bool isDefault;
  final List<AthkarItem> items;
  final AthkarReminder? reminder;
  final bool isFavorite;

  AthkarCollection copyWith({
    String? name,
    String? description,
    List<AthkarItem>? items,
    AthkarReminder? reminder,
    bool? isFavorite,
    bool clearReminder = false,
  }) {
    return AthkarCollection(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      isDefault: isDefault,
      items: items ?? this.items,
      reminder: clearReminder ? null : (reminder ?? this.reminder),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'isDefault': isDefault,
    'items': items.map((item) => item.toJson()).toList(),
    'reminder': reminder?.toJson(),
    'isFavorite': isFavorite,
  };

  factory AthkarCollection.fromJson(Map<String, dynamic> json) {
    return AthkarCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => AthkarItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      reminder: json['reminder'] == null
          ? null
          : AthkarReminder.fromJson(json['reminder'] as Map<String, dynamic>),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}

class AppSettings {
  const AppSettings({
    this.adhanEnabled = true,
    this.mutedPrayers = const {},
    this.calculationMethod = 'umm_al_qura',
    this.madhab = 'shafi',
    this.adminMode = false,
    this.adhanFilePath,
  });

  final bool adhanEnabled;
  final Set<String> mutedPrayers;
  final String calculationMethod;
  final String madhab;
  final bool adminMode;
  final String? adhanFilePath;

  bool isAdhanOn(String prayerId) =>
      adhanEnabled && !mutedPrayers.contains(prayerId);

  AppSettings copyWith({
    bool? adhanEnabled,
    Set<String>? mutedPrayers,
    String? calculationMethod,
    String? madhab,
    bool? adminMode,
    String? adhanFilePath,
    bool clearAdhanFile = false,
  }) {
    return AppSettings(
      adhanEnabled: adhanEnabled ?? this.adhanEnabled,
      mutedPrayers: mutedPrayers ?? this.mutedPrayers,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      madhab: madhab ?? this.madhab,
      adminMode: adminMode ?? this.adminMode,
      adhanFilePath: clearAdhanFile
          ? null
          : (adhanFilePath ?? this.adhanFilePath),
    );
  }

  Map<String, dynamic> toJson() => {
    'adhanEnabled': adhanEnabled,
    'mutedPrayers': mutedPrayers.toList(),
    'calculationMethod': calculationMethod,
    'madhab': madhab,
    'adminMode': adminMode,
    'adhanFilePath': adhanFilePath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      adhanEnabled: json['adhanEnabled'] as bool? ?? true,
      mutedPrayers: {
        for (final item in json['mutedPrayers'] as List<dynamic>? ?? [])
          item as String,
      },
      calculationMethod: json['calculationMethod'] as String? ?? 'umm_al_qura',
      madhab: json['madhab'] as String? ?? 'shafi',
      adminMode: json['adminMode'] as bool? ?? false,
      adhanFilePath: json['adhanFilePath'] as String?,
    );
  }
}

class CityOption {
  const CityOption({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;

  String get label => '$name — $country';
}
