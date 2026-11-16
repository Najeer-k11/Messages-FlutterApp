import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:msgs/features/inbox/bloc/inbox_bloc.dart';
import 'package:msgs/features/inbox/bloc/inbox_event.dart';
import 'package:msgs/features/permissions/permission_screen.dart';
import 'package:msgs/services/sms/models/message_model.dart';
import 'package:msgs/services/sms/models/read_state_model.dart';
import 'package:msgs/services/sms/models/thread_model.dart';
import 'package:msgs/services/sms/repository/sms_repository.dart';
import 'package:msgs/services/wallpaper/wallpaper_colors.dart';
import 'package:msgs/ui/ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _registerLicenses();

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open([ThreadModelSchema, MessageModelSchema, ReadStateModelSchema], directory: dir.path);

  final smsRepository = SmsRepository(isar: isar);
  final (themeSettings, wallpaper) = await (ThemeSettingsNotifier.create(), WallpaperColorsNotifier.create()).wait;

  runApp(MsgsApp(smsRepository: smsRepository, themeSettings: themeSettings, wallpaper: wallpaper));
}

void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Google Sans Flex'], await rootBundle.loadString('licenses/OFL-1.1.txt'));
    yield LicenseEntryWithLineBreaks([
      'Material Expressive design system (Expressive Clock, Material Clock)',
    ], await rootBundle.loadString('licenses/LICENSE-MIT-material-clock.txt'));
  });
}

class MsgsApp extends StatelessWidget {
  const MsgsApp({super.key, required this.smsRepository, required this.themeSettings, required this.wallpaper});

  final SmsRepository smsRepository;
  final ThemeSettingsNotifier themeSettings;
  final WallpaperColorsNotifier wallpaper;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        RepositoryProvider.value(value: smsRepository),
        ChangeNotifierProvider<ThemeSettingsNotifier>.value(value: themeSettings),
      ],
      child: BlocProvider(
        create: (context) => InboxBloc(smsRepository: smsRepository)..add(SyncInboxEvent()),
        child: ListenableBuilder(
          listenable: Listenable.merge([themeSettings, wallpaper]),
          builder: (context, _) {
            final settings = themeSettings.value;
            final schemes = wallpaper.value;
            final light = resolveScheme(settings: settings, dark: false, wallpaper: schemes.light);
            final dark = resolveScheme(settings: settings, dark: true, wallpaper: schemes.dark);
            return Provider<WallpaperSchemes>.value(
              value: schemes,
              child: MaterialApp(
                title: 'Messages',
                debugShowCheckedModeBanner: false,
                theme: buildExpressiveTheme(light),
                darkTheme: buildExpressiveTheme(dark),
                themeMode: settings.darkMode.themeMode,
                themeAnimationDuration: Motion.colour,
                builder: (context, child) =>
                    AnnotatedRegion<SystemUiOverlayStyle>(value: overlayStyleFor(context.isAppDark), child: child!),
                home: const PermissionScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
