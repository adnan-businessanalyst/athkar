import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_hosts.dart';
import '../services/prayer_times_service.dart';
import '../state/athkar_store.dart';
import 'auth_screen.dart';
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
          const _SectionTitle('الحساب والمزامنة'),
          if (store.isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(store.accountEmail ?? ''),
              subtitle: Text(
                store.syncInProgress
                    ? 'جارٍ المزامنة...'
                    : store.pendingSync
                    ? 'في انتظار المزامنة'
                    : store.lastSyncedAt == null
                    ? 'لم تُزامَن بعد'
                    : 'آخر مزامنة ${store.lastSyncedAt!.hour.toString().padLeft(2, '0')}:${store.lastSyncedAt!.minute.toString().padLeft(2, '0')}',
              ),
              trailing: IconButton(
                tooltip: 'مزامنة الآن',
                onPressed: store.syncInProgress ? null : () => store.syncNow(),
                icon: const Icon(Icons.sync),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
              onTap: () => store.logout(),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('حذف الحساب'),
              subtitle: const Text('يحذف الحساب من الخادم. البيانات المحلية تبقى على هذا الجهاز.'),
              onTap: () => _confirmDelete(context, store),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('تسجيل الدخول'),
              subtitle: const Text('اختياري. الضيف يعمل دون إنترنت.'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
                );
              },
            ),
          const Divider(),
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
                  : 'أذان افتراضي: محمد بن موسى',
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
          const _SectionTitle('التذكيرات'),
          const ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('تذكير الأذكار'),
            subtitle: Text(
              'افتح أي قائمة ثم أيقونة الجرس لتحديد وقت يومي.',
            ),
          ),
          const Divider(),
          const _SectionTitle('حول'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('سياسة الخصوصية'),
            subtitle: Text(AppHosts.privacyUrl),
            onTap: () async {
              final uri = Uri.parse(AppHosts.privacyUrl);
              final opened = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppHosts.privacyUrl)),
                );
              }
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

  Future<void> _confirmDelete(BuildContext context, AthkarStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف الحساب؟'),
          content: const Text(
            'سيُحذف الحساب من الخادم ولن يمكن الدخول به. بيانات هذا الجهاز تبقى محلية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      try {
        await store.deleteRemoteAccount();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
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
