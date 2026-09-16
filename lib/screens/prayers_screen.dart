import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../state/athkar_store.dart';
import '../theme/app_theme.dart';
import 'location_screen.dart';

class PrayersScreen extends StatelessWidget {
  const PrayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final prayers = store.today;
    final next = prayers?.currentOrNext;
    final timeFormat = DateFormat.jm('ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(
            tooltip: 'تغيير الموقع',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LocationScreen(),
                ),
              );
            },
            icon: const Icon(Icons.edit_location_alt_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _LocationCard(store: store),
          const SizedBox(height: 16),
          if (prayers == null)
            const _EmptyPrayers()
          else ...[
            if (next != null) _NextPrayerCard(slot: next, format: timeFormat),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < prayers.slots.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _PrayerTile(
                      slot: prayers.slots[i],
                      format: timeFormat,
                      isNext: next?.id == prayers.slots[i].id,
                      adhanOn: prayers.slots[i].isSunrise
                          ? false
                          : store.settings.isAdhanOn(prayers.slots[i].id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تشغيل الأذان عند دخول الوقت'),
              subtitle: const Text(
                'إشعار في الخلفية، وتشغيل الملف الصوتي إن وُجد والتطبيق مفتوح',
              ),
              value: store.settings.adhanEnabled,
              onChanged: (value) {
                store.updateSettings(
                  store.settings.copyWith(adhanEnabled: value),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.store});

  final AthkarStore store;

  @override
  Widget build(BuildContext context) {
    final location = store.location;
    return Card(
      color: AppTheme.seed.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(
          location?.source == LocationSource.gps
              ? Icons.my_location
              : Icons.location_on_outlined,
          color: AppTheme.seed,
        ),
        title: Text(location?.label ?? 'لم يُحدد موقع بعد'),
        subtitle: Text(
          location == null
              ? 'اختر مدينة أو استخدم موقع الجهاز لحساب المواقيت'
              : '${location.latitude.toStringAsFixed(3)}، ${location.longitude.toStringAsFixed(3)}',
        ),
        trailing: store.loadingLocation
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_left),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LocationScreen()),
          );
        },
      ),
    );
  }
}

class _EmptyPrayers extends StatelessWidget {
  const _EmptyPrayers();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.mosque_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'حدد موقعك لعرض مواقيت الصلاة وتشغيل الأذان.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({required this.slot, required this.format});

  final PrayerSlot slot;
  final DateFormat format;

  @override
  Widget build(BuildContext context) {
    final remaining = slot.time.difference(DateTime.now());
    final countdown = remaining.isNegative
        ? 'الآن'
        : _formatRemaining(remaining);

    return Card(
      color: AppTheme.seed,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slot.time.isAfter(DateTime.now()) ? 'الصلاة القادمة' : 'حان الوقت',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              slot.arabicName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${format.format(slot.time)}  ·  $countdown',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return 'بعد $hours س و $minutes د';
    }
    if (minutes > 0) {
      return 'بعد $minutes د و $seconds ث';
    }
    return 'بعد $seconds ث';
  }
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({
    required this.slot,
    required this.format,
    required this.isNext,
    required this.adhanOn,
  });

  final PrayerSlot slot;
  final DateFormat format;
  final bool isNext;
  final bool adhanOn;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        slot.isSunrise ? Icons.wb_sunny_outlined : Icons.nightlight_round,
        color: isNext ? AppTheme.seed : null,
      ),
      title: Text(
        slot.arabicName,
        style: TextStyle(
          fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: slot.isSunrise
          ? const Text('لا أذان للشروق')
          : Text(adhanOn ? 'الأذان مفعّل' : 'الأذان متوقف'),
      trailing: Text(
        format.format(slot.time),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
