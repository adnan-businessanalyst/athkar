import 'package:geolocator/geolocator.dart';

import '../models/models.dart';

class LocationService {
  Future<SavedLocation> detect() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException('فعّل خدمة الموقع من إعدادات الجهاز.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('لم يُسمح بالوصول إلى الموقع.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'الموقع مرفوض دائماً. اسمح به من إعدادات التطبيق.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );

    return SavedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      label: 'موقع الجهاز',
      source: LocationSource.gps,
    );
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
