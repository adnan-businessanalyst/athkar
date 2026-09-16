import '../models/models.dart';

class DefaultCollections {
  static const ids = <String>[
    'morning',
    'evening',
    'after_prayer',
    'sleep',
    'waking',
    'mosque',
  ];

  static List<AthkarCollection> seed() {
    return [
      AthkarCollection(
        id: 'morning',
        name: 'أذكار الصباح',
        description: 'بعد صلاة الفجر حتى شروق الشمس. اتركها فارغة ليُكملها المشرف أو أضف أذكارك.',
        isDefault: true,
        reminder: const AthkarReminder(enabled: false, hour: 6, minute: 0),
      ),
      AthkarCollection(
        id: 'evening',
        name: 'أذكار المساء',
        description: 'من العصر إلى المغرب. القائمة فارغة حتى تُملأ.',
        isDefault: true,
        reminder: const AthkarReminder(enabled: false, hour: 17, minute: 0),
      ),
      AthkarCollection(
        id: 'after_prayer',
        name: 'أذكار بعد الصلاة',
        description: 'ما يُقال بعد السلام من الفريضة.',
        isDefault: true,
      ),
      AthkarCollection(
        id: 'sleep',
        name: 'أذكار النوم',
        description: 'قبل النوم.',
        isDefault: true,
        reminder: const AthkarReminder(enabled: false, hour: 22, minute: 0),
      ),
      AthkarCollection(
        id: 'waking',
        name: 'أذكار الاستيقاظ',
        description: 'عند الاستيقاظ من النوم.',
        isDefault: true,
      ),
      AthkarCollection(
        id: 'mosque',
        name: 'أذكار المسجد',
        description: 'دخول المسجد والخروج منه.',
        isDefault: true,
      ),
    ];
  }

  static List<AthkarCollection> mergeMissing(List<AthkarCollection> existing) {
    final byId = {for (final collection in existing) collection.id: collection};
    final merged = <AthkarCollection>[];
    for (final preset in seed()) {
      merged.add(byId.remove(preset.id) ?? preset);
    }
    merged.addAll(byId.values);
    return merged;
  }
}
