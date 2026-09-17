import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:athkar/app.dart';
import 'package:athkar/data/local/database.dart';
import 'package:athkar/state/athkar_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<AthkarStore> createStore() async {
    SharedPreferences.setMockInitialValues({});
    final store = AthkarStore(
      enableForegroundAdhanWatch: false,
      enableCloudSync: false,
      database: AppDatabase.memory(),
    );
    await store.init();
    return store;
  }

  Future<void> pumpApp(WidgetTester tester, AthkarStore store) async {
    await tester.pumpWidget(AthkarApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('app shell is Arabic RTL with four tabs', (tester) async {
    final store = await createStore();
    await pumpApp(tester, store);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.rtl,
      ),
      findsWidgets,
    );

    expect(find.text('الصلاة'), findsWidgets);
    expect(find.text('الأذكار'), findsWidgets);
    expect(find.text('العداد'), findsWidgets);
    expect(find.text('الإعدادات'), findsWidgets);
    expect(
      find.text('حدد موقعك لعرض مواقيت الصلاة وتشغيل الأذان.'),
      findsOneWidget,
    );
  });

  testWidgets('wide window uses a side navigation rail', (tester) async {
    final store = await createStore();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, store);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('default athkar collections are listed empty', (tester) async {
    final store = await createStore();
    await pumpApp(tester, store);

    await tester.tap(find.text('الأذكار').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('أذكار الصباح'), findsOneWidget);
    expect(find.text('أذكار المساء'), findsOneWidget);
    expect(find.text('أذكار بعد الصلاة'), findsOneWidget);
    expect(find.textContaining('فارغة'), findsWidgets);
  });

  testWidgets('counter can be created and incremented', (tester) async {
    final store = await createStore();
    await pumpApp(tester, store);

    await tester.tap(find.text('العداد').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('عداد جديد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'تسبيح');
    await tester.tap(find.text('حفظ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('تسبيح'), findsOneWidget);
    await tester.tap(find.byTooltip('زيادة'));
    await tester.pump();
    expect(store.counters.single.count, 1);
  });

  testWidgets('settings expose adhan and reminders', (tester) async {
    final store = await createStore();
    await pumpApp(tester, store);

    await tester.tap(find.text('الإعدادات').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('وضع المشرف'), findsNothing);
    await tester.scrollUntilVisible(find.text('ملف الأذان'), 400);
    expect(find.text('ملف الأذان'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('تذكير الأذكار'), 400);
    expect(find.text('تذكير الأذكار'), findsOneWidget);
  });

  test('store persists named counters and custom athkar', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AthkarStore(
      enableForegroundAdhanWatch: false,
      enableCloudSync: false,
      database: AppDatabase.memory(),
    );
    await store.init();

    await store.addCounter('استغفار');
    await store.incrementCounter(store.counters.single.id);
    expect(store.counters.single.name, 'استغفار');
    expect(store.counters.single.count, 1);

    await store.addCollection(name: 'أذكاري');
    final custom = store.collections.last;
    await store.addItem(
      collectionId: custom.id,
      text: 'سبحان الله',
      repeatCount: 3,
    );
    expect(store.collectionById(custom.id)!.items.single.text, 'سبحان الله');

    final morning = store.collectionById('morning')!;
    expect(morning.items, isEmpty);
    expect(morning.isDefault, isTrue);
    store.dispose();
  });
}
