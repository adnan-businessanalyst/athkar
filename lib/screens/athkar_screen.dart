import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/athkar_store.dart';
import '../theme/app_theme.dart';
import 'athkar_collection_screen.dart';

class AthkarScreen extends StatefulWidget {
  const AthkarScreen({super.key});

  @override
  State<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends State<AthkarScreen> {
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final collections = store.collections
        .where((collection) => !_favoritesOnly || collection.isFavorite)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأذكار'),
        actions: [
          IconButton(
            tooltip: 'المفضلة فقط',
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
            icon: Icon(_favoritesOnly ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCollection(context, store),
        icon: const Icon(Icons.add),
        label: const Text('قائمة جديدة'),
      ),
      body: collections.isEmpty
          ? Center(
              child: Text(
                _favoritesOnly
                    ? 'لا توجد قوائم في المفضلة.'
                    : 'لا توجد قوائم بعد.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: collections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final collection = collections[index];
                return _CollectionCard(
                  collection: collection,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AthkarCollectionScreen(collectionId: collection.id),
                      ),
                    );
                  },
                  onFavorite: () => store.toggleFavorite(collection.id),
                );
              },
            ),
    );
  }

  Future<void> _createCollection(
    BuildContext context,
    AthkarStore store,
  ) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('قائمة أذكار جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم القائمة'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'وصف اختياري'),
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
              child: const Text('إنشاء'),
            ),
          ],
        );
      },
    );
    if (created == true) {
      await store.addCollection(
        name: name.text,
        description: description.text,
      );
    }
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.onOpen,
    required this.onFavorite,
  });

  final AthkarCollection collection;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final reminder = collection.reminder;
    final reminderLabel = reminder != null && reminder.enabled
        ? 'تذكير ${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}'
        : 'بدون تذكير';

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      collection.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (collection.isDefault)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Chip(
                        label: Text('أساسية'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  IconButton(
                    onPressed: onFavorite,
                    icon: Icon(
                      collection.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: collection.isFavorite ? Colors.redAccent : null,
                    ),
                  ),
                ],
              ),
              if (collection.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  collection.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.format_list_numbered,
                        size: 18,
                        color: AppTheme.seed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        collection.items.isEmpty
                            ? 'فارغة — جاهزة للتعبئة'
                            : '${collection.items.length} ذكر',
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 18,
                        color: AppTheme.gold,
                      ),
                      const SizedBox(width: 6),
                      Text(reminderLabel),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
