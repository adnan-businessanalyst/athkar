import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/athkar_store.dart';
import '../theme/app_theme.dart';
import 'counter_tap_screen.dart';

class CountersScreen extends StatelessWidget {
  const CountersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('عداد الأذكار')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _promptName(context, store),
        icon: const Icon(Icons.add),
        label: const Text('عداد جديد'),
      ),
      body: store.counters.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'أنشئ عدّاداً باسمك، ثم اضغط لزيادة العدد. يُحفظ العدّ تلقائياً.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: store.counters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final counter = store.counters[index];
                return _CounterCard(
                  counter: counter,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CounterTapScreen(counterId: counter.id),
                      ),
                    );
                  },
                  onIncrement: () {
                    HapticFeedback.lightImpact();
                    store.incrementCounter(counter.id);
                  },
                  onRename: () => _promptName(
                    context,
                    store,
                    id: counter.id,
                    initial: counter.name,
                  ),
                  onReset: () => store.resetCounter(counter.id),
                  onDelete: () => store.deleteCounter(counter.id),
                );
              },
            ),
    );
  }

  Future<void> _promptName(
    BuildContext context,
    AthkarStore store, {
    String? id,
    String? initial,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(id == null ? 'عداد جديد' : 'إعادة تسمية'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم العداد'),
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
      if (id == null) {
        await store.addCounter(controller.text);
      } else {
        await store.renameCounter(id, controller.text);
      }
    }
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.counter,
    required this.onOpen,
    required this.onIncrement,
    required this.onRename,
    required this.onReset,
    required this.onDelete,
  });

  final AthkarCounter counter;
  final VoidCallback onOpen;
  final VoidCallback onIncrement;
  final VoidCallback onRename;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        title: Text(
          counter.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('اضغط للتسبيح بكامل الشاشة'),
        leading: CircleAvatar(
          backgroundColor: AppTheme.seed.withValues(alpha: 0.12),
          foregroundColor: AppTheme.seed,
          child: FittedBox(
            child: Text(
              '${counter.count}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'زيادة',
              onPressed: onIncrement,
              icon: const Icon(Icons.add_circle_outline),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename();
                  case 'reset':
                    onReset();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
                PopupMenuItem(value: 'reset', child: Text('تصفير')),
                PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
