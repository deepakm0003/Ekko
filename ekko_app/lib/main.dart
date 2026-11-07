import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/app_data.dart';
import 'screens/lock.dart';
import 'screens/login.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'services/auth_service.dart';
import 'services/secure_store.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const EkkoBoot());
}

/// Loads reference data behind a branded splash, then starts the app.
class EkkoBoot extends StatefulWidget {
  const EkkoBoot({super.key});
  @override
  State<EkkoBoot> createState() => _EkkoBootState();
}

class _EkkoBootState extends State<EkkoBoot> {
  AppState? _state;
  bool _languageChosen = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final data = await AppData.load();
      final s = AppState(data);
      await s.init();
      _languageChosen = await SecureStore.language() != null;
      setState(() => _state = s);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEkkoTheme(),
        home: Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const EkkoLogo(size: 56),
              const SizedBox(height: 24),
              if (_error == null)
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))
              else
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not start: $_error', textAlign: TextAlign.center),
                ),
            ]),
          ),
        ),
      );
    }
    return ChangeNotifierProvider.value(
      value: _state!,
      child: EkkoApp(languageChosen: _languageChosen),
    );
  }
}

class EkkoApp extends StatefulWidget {
  final bool languageChosen;
  const EkkoApp({super.key, required this.languageChosen});
  @override
  State<EkkoApp> createState() => _EkkoAppState();
}

class _EkkoAppState extends State<EkkoApp> with WidgetsBindingObserver {
  late bool _onboarded = widget.languageChosen;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-lock after 60 s in the background when app lock is on.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!) > const Duration(seconds: 60)) {
        context.read<AppState>().lockIfEnabled();
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Widget home;
    if (!_onboarded) {
      home = OnboardingScreen(onDone: () => setState(() => _onboarded = true));
    } else if (app.user == null) {
      home = const LoginScreen();
    } else if (app.locked) {
      home = const LockScreen();
    } else {
      home = app.user!.role == Role.partner ? const PartnerShell() : const OwnerShell();
    }
    return MaterialApp(
      title: 'Ekko',
      debugShowCheckedModeBanner: false,
      theme: buildEkkoTheme(),
      home: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: home),
    );
  }
}
