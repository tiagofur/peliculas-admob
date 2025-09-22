import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const appVersion = '1.2.1+6'; // Hardcoded version from pubspec.yaml
    final l10n = AppLocalizations.of(context);

    // Safe fallback text when localizations are not available
    final aboutText = l10n?.about ?? 'About';
    final versionText = l10n?.version ?? 'Version';
    final developedByText = l10n?.developedBy ?? 'Developed by';
    final privacyPolicyText = l10n?.privacyPolicy ?? 'Privacy Policy';

    return Scaffold(
      appBar: AppBar(
        title: Text(aboutText),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(versionText),
            subtitle: const Text(appVersion),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(developedByText),
            subtitle: const Text('Tu Nombre o Nombre de tu Compañía'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(privacyPolicyText),
            onTap: () {
              context.push('/privacy-policy');
            },
          ),
        ],
      ),
    );
  }
}
