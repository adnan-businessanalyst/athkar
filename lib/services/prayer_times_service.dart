import 'package:adhan/adhan.dart';

import '../models/models.dart';

class PrayerTimesService {
  static const methods = <String, String>{
    'umm_al_qura': 'أم القرى — مكة',
    'muslim_world_league': 'رابطة العالم الإسلامي',
    'egyptian': 'الهيئة المصرية',
    'karachi': 'جامعة العلوم الإسلامية — كراتشي',
    'dubai': 'دبي',
    'qatar': 'قطر',
    'kuwait': 'الكويت',
    'singapore': 'سنغافورة',
    'turkey': 'تركيا',
    'north_america': 'إسنا — أمريكا الشمالية',
  };

  DailyPrayers calculate({
    required SavedLocation location,
    required String method,
    required String madhab,
    DateTime? date,
  }) {
    final coordinates = Coordinates(location.latitude, location.longitude);
    final params = _parameters(method);
    params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    final day = date ?? DateTime.now();
    final times = PrayerTimes(
      coordinates,
      DateComponents(day.year, day.month, day.day),
      params,
    );

    return DailyPrayers(
      date: DateTime(day.year, day.month, day.day),
      slots: [
        PrayerSlot(id: 'fajr', arabicName: 'الفجر', time: times.fajr),
        PrayerSlot(
          id: 'sunrise',
          arabicName: 'الشروق',
          time: times.sunrise,
          isSunrise: true,
        ),
        PrayerSlot(id: 'dhuhr', arabicName: 'الظهر', time: times.dhuhr),
        PrayerSlot(id: 'asr', arabicName: 'العصر', time: times.asr),
        PrayerSlot(id: 'maghrib', arabicName: 'المغرب', time: times.maghrib),
        PrayerSlot(id: 'isha', arabicName: 'العشاء', time: times.isha),
      ],
    );
  }

  CalculationParameters _parameters(String method) {
    return switch (method) {
      'muslim_world_league' =>
        CalculationMethod.muslim_world_league.getParameters(),
      'egyptian' => CalculationMethod.egyptian.getParameters(),
      'karachi' => CalculationMethod.karachi.getParameters(),
      'dubai' => CalculationMethod.dubai.getParameters(),
      'qatar' => CalculationMethod.qatar.getParameters(),
      'kuwait' => CalculationMethod.kuwait.getParameters(),
      'singapore' => CalculationMethod.singapore.getParameters(),
      'turkey' => CalculationMethod.turkey.getParameters(),
      'north_america' => CalculationMethod.north_america.getParameters(),
      _ => CalculationMethod.umm_al_qura.getParameters(),
    };
  }
}
