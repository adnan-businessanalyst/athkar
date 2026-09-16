import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/athkar_store.dart';
import '../theme/app_theme.dart';

class CounterTapScreen extends StatelessWidget {
  const CounterTapScreen({super.key, required this.counterId});

  final String counterId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final counter = store.counterById(counterId);
    if (counter == null) {
      return const Scaffold(body: Center(child: Text('العداد غير موجود')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(counter.name),
        actions: [
          TextButton(
            onPressed: () => store.resetCounter(counter.id),
            child: const Text('تصفير'),
          ),
        ],
      ),
      body: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          store.incrementCounter(counter.id);
        },
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${counter.count}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.seed,
                  fontSize: 88,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اضغط في أي مكان للزيادة',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
