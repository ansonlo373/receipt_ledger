import 'package:flutter/material.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/models/receipt_filter.dart';
import 'package:receipt_ledger/utils/formatters.dart';

const _quickPresets = [
  'Today',
  'This week',
  'This month',
  'Last month',
  'This year',
];

DateTimeRange _presetRange(String preset) {
  final now = DateUtils.dateOnly(DateTime.now());
  switch (preset) {
    case 'Today':
      return DateTimeRange(start: now, end: now);
    case 'This week':
      final start = now.subtract(Duration(days: now.weekday - 1));
      return DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 6)),
      );
    case 'This month':
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
    case 'Last month':
      return DateTimeRange(
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0),
      );
    case 'This year':
      return DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31),
      );
  }
  throw ArgumentError('Unknown preset: $preset');
}

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key, required this.initialFilter});

  final ReceiptFilter initialFilter;

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late Set<ReceiptCategory> _categories;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _categories = Set.of(widget.initialFilter.categories);
    _dateRange = widget.initialFilter.dateRange;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(
        () => _dateRange = DateTimeRange(
          start: DateUtils.dateOnly(picked.start),
          end: DateUtils.dateOnly(picked.end),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        leadingWidth: 88,
        title: const Text('Filter'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              ReceiptFilter(categories: _categories, dateRange: _dateRange),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Quick range', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _quickPresets)
                ChoiceChip(
                  label: Text(preset),
                  selected: _dateRange == _presetRange(preset),
                  onSelected: (_) =>
                      setState(() => _dateRange = _presetRange(preset)),
                ),
              ActionChip(
                label: const Text('Custom'),
                onPressed: _pickCustomRange,
              ),
            ],
          ),
          if (_dateRange != null) ...[
            const SizedBox(height: 12),
            Text(
              '${dateFormat.format(_dateRange!.start)} – ${dateFormat.format(_dateRange!.end)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          Text('Category', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in ReceiptCategory.values)
                FilterChip(
                  label: Text(category.label),
                  selected: _categories.contains(category),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _categories.add(category);
                    } else {
                      _categories.remove(category);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => setState(() {
              _categories = {};
              _dateRange = null;
            }),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}
