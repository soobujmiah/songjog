import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_services.dart';
import 'domain/models/business_profile.dart';
import 'l10n/app_text.dart';
import 'presentation/welcome/welcome_page.dart';
import 'presentation/workspace/workspace_home_page.dart';

const _localeKey = 'songjog_locale';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedLocale = prefs.getString(_localeKey);
  final initialLocale = savedLocale == 'english' ? AppLocale.english : AppLocale.bangla;

  final services = await AppServices.create(locale: initialLocale);
  _installGlobalErrorHandlers(services);

  runApp(SongjogApp(services: services, locale: initialLocale));
}

/// Routes uncaught framework and platform errors into the diagnostic
/// collector so they appear in the diagnostic export without masking the
/// default handling.
void _installGlobalErrorHandlers(AppServices services) {
  final diagnostics = services.diagnostics;

  FlutterError.onError = (details) {
    diagnostics.record(
      level: 'error',
      category: 'render',
      operation: 'flutter_error',
      message: details.exceptionAsString(),
      error: details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    diagnostics.record(
      level: 'error',
      category: 'other',
      operation: 'unhandled_exception',
      message: error.toString(),
      stackTrace: stack.toString(),
    );
    return true;
  };
}

class SongjogApp extends StatefulWidget {
  const SongjogApp({super.key, required this.services, this.locale = AppLocale.bangla});

  final AppServices services;
  final AppLocale locale;

  @override
  State<SongjogApp> createState() => _SongjogAppState();
}

class _SongjogAppState extends State<SongjogApp> {
  late final Future<BusinessProfile?> _profile =
      widget.services.repository.getProfile();
  late AppLocale _locale = widget.locale;

  void _setLocale(AppLocale locale) async {
    if (_locale != locale) {
      setState(() => _locale = locale);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale == AppLocale.bangla ? 'bangla' : 'english');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppText.get(_locale, 'app_name'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF126B5A),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
      ),
      home: FutureBuilder<BusinessProfile?>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == null
              ? WelcomePage(
                  services: widget.services,
                  locale: _locale,
                  onLocaleChanged: _setLocale,
                )
              : WorkspaceHomePage(
                  services: widget.services,
                  locale: _locale,
                  onLocaleChanged: _setLocale,
                );
        },
      ),
    );
  }
}
