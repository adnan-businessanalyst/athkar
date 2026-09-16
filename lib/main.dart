import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'desktop.dart';
import 'state/athkar_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDesktopWindow();
  await initializeDateFormatting('ar');
  final store = AthkarStore();
  await store.init();
  runApp(AthkarApp(store: store));
}
