import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../services/monetization/adaptive_monetization_manager.dart';
import '../../services/monetization/purchases_service.dart';
import '../../services/monetization/user_monetization_preferences_service.dart';

/// Paywall de Películas Pro: compra lifetime + restaurar compras.
///
/// Apple exige Restore visible y cero pagos externos: ambos botones viven
/// aquí y no hay links fuera del IAP (S4, S5).
class ProPaywallScreen extends StatefulWidget {
  const ProPaywallScreen({super.key});

  @override
  State<ProPaywallScreen> createState() => _ProPaywallScreenState();
}

class _ProPaywallScreenState extends State<ProPaywallScreen> {
  final PurchasesService _purchases = LocalPurchasesService.instance;
  bool? _isPro;
  bool? _breakActive;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final isPro = await _purchases.isPro();
    final breakActive = await UserMonetizationPreferencesService.instance
        .isAdBreakActive();
    if (!mounted) return;
    setState(() {
      _isPro = isPro;
      _breakActive = breakActive;
    });
  }

  Future<void> _buy(AppLocalizations l10n) async {
    setState(() => _busy = true);
    final entitlement = await _purchases.purchasePro();
    if (!mounted) return;
    setState(() {
      _isPro = entitlement.isPro;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.proActive)),
    );
  }

  /// Recompensa opt-in: ver un anuncio otorga 24 h sin forzados (S1).
  Future<void> _watchAd(AppLocalizations l10n) async {
    setState(() => _busy = true);
    final ok = await AdaptiveMonetizationManager.instance.showRewardedAd(
      onRewardEarned: (_) async {
        await UserMonetizationPreferencesService.instance
            .grantAdBreak(const Duration(hours: 24));
      },
      context: 'pro_paywall',
    );
    if (!mounted) return;
    await _refresh();
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.proBreakActive : l10n.rewardedUnavailable),
      ),
    );
  }

  Future<void> _restore(AppLocalizations l10n) async {
    setState(() => _busy = true);
    final entitlement = await _purchases.restorePurchases();
    if (!mounted) return;
    setState(() {
      _isPro = entitlement.isPro;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entitlement.isPro ? l10n.proActive : l10n.proNoPurchases,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.proTitle), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.workspace_premium,
              size: 72, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            l10n.proTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.proSubtitle,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _BenefitRow(icon: Icons.block, text: l10n.proBenefitNoAds),
          _BenefitRow(icon: Icons.palette, text: l10n.proBenefitThemes),
          _BenefitRow(icon: Icons.insights, text: l10n.proBenefitStats),
          const SizedBox(height: 16),
          if (_isPro == null)
            const Center(child: CircularProgressIndicator())
          else if (_isPro!)
            Card(
              color: colors.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.verified),
                title: Text(l10n.proActive),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _busy ? null : () => _buy(l10n),
              icon: const Icon(Icons.workspace_premium),
              label: Text(l10n.proBuy),
            ),
          if (_breakActive == true)
            Card(
              child: ListTile(
                leading: const Icon(Icons.snooze),
                title: Text(l10n.proBreakActive),
              ),
            ),
          if (_isPro == false) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _watchAd(l10n),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(l10n.proWatchAd),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : () => _restore(l10n),
            icon: const Icon(Icons.restore),
            label: Text(l10n.proRestore),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.proLifetimeNote,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
