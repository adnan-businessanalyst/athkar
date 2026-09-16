import 'package:flutter/material.dart';

import '../data/cities.dart';
import '../state/athkar_store.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final filter = _query.text.trim();
    final cities = knownCities.where((city) {
      if (filter.isEmpty) return true;
      return city.name.contains(filter) || city.country.contains(filter);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الموقع')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (store.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                store.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: store.loadingLocation
                ? null
                : () async {
                    await store.detectLocation();
                    if (context.mounted && store.location != null) {
                      Navigator.of(context).pop();
                    }
                  },
            icon: store.loadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: const Text('استخدم موقع الجهاز'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showCustomDialog(context, store),
            icon: const Icon(Icons.pin_drop_outlined),
            label: const Text('إدخال إحداثيات يدوياً'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث عن مدينة',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          for (final city in cities)
            ListTile(
              leading: const Icon(Icons.location_city_outlined),
              title: Text(city.name),
              subtitle: Text(city.country),
              selected: store.location?.city == city.name,
              onTap: () async {
                await store.selectCity(city);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showCustomDialog(BuildContext context, AthkarStore store) async {
    final name = TextEditingController();
    final lat = TextEditingController();
    final lng = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('موقع مخصص'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: lat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'خط العرض'),
              ),
              TextField(
                controller: lng,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'خط الطول'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final latitude = double.tryParse(lat.text.trim());
      final longitude = double.tryParse(lng.text.trim());
      if (latitude == null || longitude == null) return;
      await store.setCustomLocation(
        label: name.text.trim().isEmpty ? 'موقع مخصص' : name.text.trim(),
        latitude: latitude,
        longitude: longitude,
      );
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
