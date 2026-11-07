import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().unlock());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const EkkoLogo(size: 56, showName: false),
            const SizedBox(height: 20),
            const Icon(Icons.lock_outline, size: 32, color: EkkoColors.inkSoft),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: FilledButton.icon(
                onPressed: () => context.read<AppState>().unlock(),
                icon: const Icon(Icons.fingerprint),
                label: Text(context.t('unlock')),
              ),
            ),
          ]),
        ),
      );
}
