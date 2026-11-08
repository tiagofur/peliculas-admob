import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/user_subscription.dart';

/// Dialog for editing subscription details
class EditSubscriptionDialog extends StatefulWidget {
  const EditSubscriptionDialog({
    super.key,
    required this.subscription,
    required this.onSave,
  });

  final UserSubscription subscription;
  final Function(UserSubscription) onSave;

  @override
  State<EditSubscriptionDialog> createState() => _EditSubscriptionDialogState();
}

class _EditSubscriptionDialogState extends State<EditSubscriptionDialog> {
  late TextEditingController _platformController;
  late TextEditingController _costController;
  late SubscriptionType _selectedType;
  late String _selectedBillingCycle;
  late DateTime _startDate;
  late DateTime? _nextBillingDate;
  late bool _autoRenew;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _platformController =
        TextEditingController(text: widget.subscription.platformName);
    _costController =
        TextEditingController(text: widget.subscription.monthlyCost.toString());
    _selectedType = widget.subscription.type;
    _selectedBillingCycle = widget.subscription.billingCycle ?? 'monthly';
    _startDate = widget.subscription.startDate;
    _nextBillingDate = widget.subscription.nextBillingDate;
    _autoRenew = widget.subscription.autoRenew;
    _isActive = widget.subscription.isCurrentlyActive;
  }

  @override
  void dispose() {
    _platformController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Subscription'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _platformController,
              decoration: const InputDecoration(
                labelText: 'Platform Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _costController,
              decoration: const InputDecoration(
                labelText: 'Monthly Cost',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SubscriptionType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Subscription Type',
                border: OutlineInputBorder(),
              ),
              items: SubscriptionType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedBillingCycle,
              decoration: const InputDecoration(
                labelText: 'Billing Cycle',
                border: OutlineInputBorder(),
              ),
              items: ['monthly', 'yearly', 'weekly'].map((cycle) {
                return DropdownMenuItem(
                  value: cycle,
                  child: Text(_formatBillingCycle(cycle)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedBillingCycle = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(_formatDate(_startDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectStartDate(context),
                  ),
                ),
              ],
            ),
            if (_nextBillingDate != null)
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Next Billing Date'),
                      subtitle: Text(_formatDate(_nextBillingDate!)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectNextBillingDate(context),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Auto Renew'),
              value: _autoRenew,
              onChanged: (value) {
                setState(() {
                  _autoRenew = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Currently Active'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSubscription,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectNextBillingDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _nextBillingDate = date;
      });
    }
  }

  void _saveSubscription() {
    final cost = double.tryParse(_costController.text) ?? 0.0;
    if (_platformController.text.isEmpty || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
        ),
      );
      return;
    }

    final updatedSubscription = widget.subscription.copyWith(
      platformName: _platformController.text,
      monthlyCost: cost,
      type: _selectedType,
      billingCycle: _selectedBillingCycle,
      startDate: _startDate,
      nextBillingDate: _nextBillingDate,
      autoRenew: _autoRenew,
    );

    widget.onSave(updatedSubscription);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatBillingCycle(String cycle) {
    switch (cycle.toLowerCase()) {
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      case 'weekly':
        return 'Weekly';
      default:
        return cycle;
    }
  }
}
