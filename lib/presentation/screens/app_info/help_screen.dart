import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.helpAndSupport),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Text(
            l10n.faq,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ExpansionTile(
            title: Text(l10n.howToAddMovieToWatchlist),
            children: [
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Text(l10n.howToAddMovieToWatchlistAnswer),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(l10n.howDoesSyncWork),
            children: [
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Text(l10n.howDoesSyncWorkAnswer),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(l10n.howToContactSupport),
            children: [
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Text(l10n.howToContactSupportAnswer),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
