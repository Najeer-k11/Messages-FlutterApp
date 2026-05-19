import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/permissions/permission_screen.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/models/message_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open([
    ThreadModelSchema,
    MessageModelSchema,
  ], directory: dir.path);

  final smsRepository = SmsRepository(isar: isar);
  final themeNotifier = await ThemeNotifier.create();

  runApp(MsgsApp(
    smsRepository: smsRepository,
    themeNotifier: themeNotifier,
  ));
}

class MsgsApp extends StatelessWidget {
  final SmsRepository smsRepository;
  final ThemeNotifier themeNotifier;

  const MsgsApp({
    super.key,
    required this.smsRepository,
    required this.themeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        RepositoryProvider.value(value: smsRepository),
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return BlocProvider(
            create: (context) =>
                InboxBloc(smsRepository: smsRepository)..add(SyncInboxEvent()),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, themeMode, _) {
                return MaterialApp(
                  title: 'Msgs',
                  theme: AppTheme.lightTheme(lightDynamic),
                  darkTheme: AppTheme.darkTheme(darkDynamic),
                  themeMode: themeMode,
                  home: const PermissionScreen(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
