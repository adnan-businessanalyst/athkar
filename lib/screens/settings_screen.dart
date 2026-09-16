import 'package:flutter/material.dart';

import '../services/prayer_times_service.dart';
import '../state/athkar_store.dart';
import 'location_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final settings = store.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionTitle('الموقع والمواقيت'),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('الموقع'),
            subtitle: Text(store.location?.label ?? 'غير محدد'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LocationScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('طريقة الحساب'),
            subtitle: Text(
              PrayerTimesService.methods[settings.calculationMethod] ??
                  settings.calculationMethod,
            ),
            onTap: () => _pickMethod(context, store),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.account_balance_outlined),
            title: const Text('مذهب العصر حنفي'),
            subtitle: const Text('إيقاف = شافعي / مالكي / حنبلي'),
            value: settings.madhab == 'hanafi',
            onChanged: (value) {
              store.updateSettings(
                settings.copyWith(madhab: value ? 'hanafi' : 'shafi'),
              );
            },
          ),
          const Divider(),
          const _SectionTitle('الأذان'),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('تنبيه الأذان'),
            subtitle: const Text('إشعارات عند الفجر والظهر والعصر والمغرب والعشاء'),
            value: settings.adhanEnabled,
            onChanged: (value) {
              store.updateSettings(settings.copyWith(adhanEnabled: value));
            },
          ),
          if (settings.adhanEnabled)
            for (final prayer in const [
              ('fajr', 'الفجر'),
              ('dhuhr', 'الظهر'),
              ('asr', 'العصر'),
              ('maghrib', 'المغرب'),
              ('isha', 'العشاء'),
            ])
              SwitchListTile(
                title: Text('أذان ${prayer.$2}'),
                value: settings.isAdhanOn(prayer.$1),
                onChanged: (value) {
                  final muted = {...settings.mutedPrayers};
                  if (value) {
                    muted.remove(prayer.$1);
                  } else {
                    muted.add(prayer.$1);
                  }
                  store.updateSettings(settings.copyWith(mutedPrayers: muted));
                },
              ),
          ListTile(
            leading: const Icon(Icons.audio_file_outlined),
            title: const Text('ملف الأذان'),
            subtitle: Text(
              settings.adhanFilePath != null
                  ? 'تم استيراد ملف صوتي'
                  : 'ضع adhan.mp3 في assets/audio أو استورد ملفاً',
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'تجربة',
                  onPressed: () => store.testAdhan(),
                  icon: const Icon(Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'إيقاف',
                  onPressed: () => store.stopAdhan(),
                  icon: const Icon(Icons.stop),
                ),
              ],
            ),
            onTap: () => store.importAdhanFile(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'مصادر مجانية شائعة: ويكيميديا كومنز (Audio files of Adhan). '
              'يمكنك أيضاً تسجيل أذان مسجدك بعد أخذ الإذن.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const Divider(),
          const _SectionTitle('التذكيرات والمشرف'),
          const ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('تذكير الأذكار'),
            subtitle: Text(
              'افتح أي قائمة ثم أيقونة الجرس لتحديد وقت يومي. القوائم الأساسية تُترك فارغة حتى يعبئها المشرف أو تضيف أذكارك.',
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('وضع المشرف'),
            subtitle: const Text('يسمح بتعديل أسماء القوائم الأساسية'),
            value: settings.adminMode,
            onChanged: (value) {
              store.updateSettings(settings.copyWith(adminMode: value));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickMethod(BuildContext context, AthkarStore store) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            for (final entry in PrayerTimesService.methods.entries)
              ListTile(
                title: Text(entry.value),
                selected: store.settings.calculationMethod == entry.key,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        );
      },
    );
    if (selected != null) {
      await store.updateSettings(
        store.settings.copyWith(calculationMethod: selected),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
