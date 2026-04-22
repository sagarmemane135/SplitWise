import 'package:flutter/widgets.dart';

import '../app/app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplitEaseApp());
}
