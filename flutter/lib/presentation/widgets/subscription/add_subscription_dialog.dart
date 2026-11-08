import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/entities/user_subscription.dart';
import '../../../domain/entities/streaming_platform.dart';

/// Dialog for adding a new streaming subscription
class AddSubscriptionDialog extends StatefulWidget {
  const AddSubscriptionDialog({super.key});

  @override
  State<AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends State<AddSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _costController = TextEditingController();

  StreamingPlatform? _selectedPlatform;
  SubscriptionType _selectedType = SubscriptionType.premium;
  String _selectedBillingCycle = 'monthly';
  DateTime _startDate = DateTime.now();
  bool _autoRenew = true;

  final List<String> _billingCycles = [
    'monthly',
    'quarterly',
    'yearly',
  ];

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildForm(context),
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.add_circle_outline,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add Subscription',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlatformSelector(),
          const SizedBox(height: 20),
          _buildSubscriptionTypeSelector(),
          const SizedBox(height: 20),
          _buildCostField(),
          const SizedBox(height: 20),
          _buildBillingCycleSelector(),
          const SizedBox(height: 20),
          _buildStartDatePicker(),
          const SizedBox(height: 20),
          _buildAutoRenewSwitch(),
        ],
      ),
    );
  }

  Widget _buildPlatformSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Streaming Platform',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<StreamingPlatform>(
            initialValue: _selectedPlatform,
            decoration: const InputDecoration(
              hintText: 'Select a platform',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (value) {
              if (value == null) {
                return 'Please select a platform';
              }
              return null;
            },
            items: StreamingPlatform.allPlatforms.map((platform) {
              return DropdownMenuItem(
                value: platform,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(platform.displayName),
                  ],
                ),
              );
            }).toList(),
            onChanged: (platform) {
              setState(() {
                _selectedPlatform = platform;
                // Set default cost based on platform
                if (platform != null) {
                  _costController.text = _getDefaultCost(platform).toString();
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subscription Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: SubscriptionType.values.map((type) {
            final isSelected = _selectedType == type;
            return FilterChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedType = type;
                  });
                }
              },
              backgroundColor: Colors.grey[100],
              selectedColor:
                  Theme.of(context).primaryColor.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCostField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Cost',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _costController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: '0.00',
            prefixText: '\$ ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the monthly cost';
            }
            final cost = double.tryParse(value);
            if (cost == null || cost <= 0) {
              return 'Please enter a valid cost';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBillingCycleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billing Cycle',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedBillingCycle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _billingCycles.map((cycle) {
              return DropdownMenuItem(
                value: cycle,
                child: Text(_formatBillingCycle(cycle)),
              );
            }).toList(),
            onChanged: (cycle) {
              if (cycle != null) {
                setState(() {
                  _selectedBillingCycle = cycle;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStartDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start Date',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectStartDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Text(
                  '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoRenewSwitch() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto Renew',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Automatically renew this subscription',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
        Switch(
          value: _autoRenew,
          onChanged: (value) {
            setState(() {
              _autoRenew = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _addSubscription,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Add Subscription'),
            ),
          ),
        ],
      ),
    );
  }

  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  void _addSubscription() {
    if (_formKey.currentState?.validate() ?? false) {
      final cost = double.parse(_costController.text);

      final subscription = UserSubscription.create(
        platformId: _selectedPlatform!.id,
        platformName: _selectedPlatform!.name,
        type: _selectedType,
        monthlyCost: cost,
        startDate: _startDate,
        billingCycle: _selectedBillingCycle,
        metadata: {
          'added_via': 'manual_dialog',
          'platform_id': _selectedPlatform!.id,
        },
      );

      Navigator.of(context).pop(subscription);
    }
  }

  double _getDefaultCost(StreamingPlatform platform) {
    // Default costs for popular platforms
    switch (platform.id) {
      case 'netflix':
        return 15.49;
      case 'prime_video':
        return 8.99;
      case 'disney_plus':
        return 7.99;
      case 'hbo_max':
        return 14.99;
      case 'hulu':
        return 7.99;
      case 'apple_tv':
        return 6.99;
      case 'paramount_plus':
        return 5.99;
      case 'peacock':
        return 4.99;
      default:
        return 9.99;
    }
  }

  String _formatBillingCycle(String cycle) {
    switch (cycle.toLowerCase()) {
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly (3 months)';
      case 'yearly':
        return 'Yearly (12 months)';
      default:
        return cycle;
    }
  }
}
