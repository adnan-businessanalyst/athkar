import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/athkar_store.dart';
import '../theme/app_theme.dart';

class AthkarCollectionScreen extends StatelessWidget {
  const AthkarCollectionScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final collection = store.collectionById(collectionId);
    if (collection == null) {
      return const Scaffold(body: Center(child: Text('القائمة غير موجودة')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            tooltip: 'تذكير',
            onPressed: () => _editReminder(context, store, collection),
            icon: Icon(
              collection.reminder?.enabled == true
                  ? Icons.notifications_active
                  : Icons.notifications_outlined,
            ),
          ),
          IconButton(
            tooltip: 'إعادة العدّ',
            onPressed: () => store.resetCollectionProgress(collection.id),
            icon: const Icon(Icons.refresh),
          ),
          if (store.settings.adminMode || !collection.isDefault)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await _editMeta(context, store, collection);
                } else if (value == 'delete') {
                  await store.deleteCollection(collection.id);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل الاسم')),
                if (!collection.isDefault)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف القائمة'),
                  ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context, store, collection.id),
        icon: const Icon(Icons.add),
        label: const Text('إضافة ذكر'),
      ),
      body: collection.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'هذه القائمة فارغة.\nيمكن للمشرف تعبئتها لاحقاً، أو أضف أذكارك الآن.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: collection.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = collection.items[index];
                return _DhikrCard(
                  item: item,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    store.tickItem(collection.id, item.id);
                  },
                  onEdit: () => _editItem(context, store, collection.id, item),
                  onDelete: () => store.deleteItem(collection.id, item.id),
                );
              },
            ),
    );
  }

  Future<void> _addItem(
    BuildContext context,
    AthkarStore store,
    String collectionId,
  ) async {
    final text = TextEditingController();
    final repeats = TextEditingController(text: '1');
    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ذكر جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'نص الذكر'),
              ),
              TextField(
                controller: repeats,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد التكرار'),
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
    if (added == true) {
      await store.addItem(
        collectionId: collectionId,
        text: text.text,
        repeatCount: int.tryParse(repeats.text) ?? 1,
      );
    }
  }

  Future<void> _editItem(
    BuildContext context,
    AthkarStore store,
    String collectionId,
    AthkarItem item,
  ) async {
    final text = TextEditingController(text: item.text);
    final repeats = TextEditingController(text: '${item.repeatCount}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل الذكر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'نص الذكر'),
              ),
              TextField(
                controller: repeats,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد التكرار'),
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
    if (saved == true) {
      await store.updateItem(
        collectionId,
        item.copyWith(
          text: text.text.trim(),
          repeatCount: int.tryParse(repeats.text) ?? item.repeatCount,
        ),
      );
    }
  }

  Future<void> _editMeta(
    BuildContext context,
    AthkarStore store,
    AthkarCollection collection,
  ) async {
    final name = TextEditingController(text: collection.name);
    final description = TextEditingController(text: collection.description);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل القائمة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'الوصف'),
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
    if (saved == true) {
      await store.updateCollection(
        collection.copyWith(
          name: name.text.trim(),
          description: description.text.trim(),
        ),
      );
    }
  }

  Future<void> _editReminder(
    BuildContext context,
    AthkarStore store,
    AthkarCollection collection,
  ) async {
    final current = collection.reminder ??
        const AthkarReminder(enabled: false, hour: 7, minute: 0);
    var enabled = current.enabled;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'وقت التذكير اليومي',
    );
    if (!context.mounted) return;
    if (picked == null && enabled) {
      await store.setReminder(
        collection.id,
        current.copyWith(enabled: false),
      );
      return;
    }
    if (picked == null) return;

    enabled = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('تفعيل التذكير؟'),
              content: Text(
                'سيصلك تنبيه يومي الساعة ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إيقاف'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تفعيل'),
                ),
              ],
            );
          },
        ) ??
        false;

    await store.setReminder(
      collection.id,
      AthkarReminder(
        enabled: enabled,
        hour: picked.hour,
        minute: picked.minute,
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final AthkarItem item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final remaining = (item.repeatCount - item.progress).clamp(0, item.repeatCount);
    return Card(
      color: item.isDone
          ? AppTheme.seed.withValues(alpha: 0.08)
          : Theme.of(context).cardColor,
      child: InkWell(
        onTap: item.isDone ? null : onTap,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.7,
                  decoration: item.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(
                      item.isDone ? 'تم' : 'المتبقي $remaining / ${item.repeatCount}',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
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
