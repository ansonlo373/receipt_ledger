import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/month_summary.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/models/trend_data.dart';
import 'package:receipt_ledger/utils/category_colors.dart';
import 'package:receipt_ledger/utils/formatters.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.repository});

  final ReceiptRepository repository;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200) {
      _shiftMonth(1);
    } else if (velocity > 200) {
      _shiftMonth(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shiftMonth(-1),
            ),
            Text(monthFormat.format(_month)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shiftMonth(1),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Receipt>>(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          final receipts = snapshot.data ?? const [];
          final summary = MonthSummary.of(receipts, _month);

          return Column(
            children: [
              // Swipe is scoped to just the donut/legend area so it doesn't
              // fight the trends section's own chip scrolling below.
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: _onHorizontalSwipe,
                  behavior: HitTestBehavior.translucent,
                  child: summary.allCategories.isEmpty
                      ? const Center(child: Text('No receipts yet this month'))
                      : ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Center(
                              child: SizedBox(
                                width: 180,
                                height: 180,
                                child: CustomPaint(
                                  painter: _DonutPainter(
                                    categories: summary.allCategories,
                                    total: summary.totalYen,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Total',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                        Text(
                                          currencyFormat.format(
                                            summary.totalYen,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            for (final category in summary.allCategories)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color:
                                            categoryColors[category.category],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(category.category.label),
                                    ),
                                    Text(
                                      '${(category.amountYen / summary.totalYen * 100).round()}%',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 72,
                                      child: Text(
                                        currencyFormat.format(
                                          category.amountYen,
                                        ),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _TrendsSection(receipts: receipts)),
            ],
          );
        },
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.categories, required this.total});

  final List<CategoryTotal> categories;
  final int total;

  static const _strokeWidth = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final rect = (Offset.zero & size).deflate(_strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    var startAngle = -math.pi / 2;
    for (final category in categories) {
      final sweep = (category.amountYen / total) * 2 * math.pi;
      paint.color = categoryColors[category.category] ?? Colors.grey;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.categories != categories || oldDelegate.total != total;
  }
}

class _TrendsSection extends StatefulWidget {
  const _TrendsSection({required this.receipts});

  final List<Receipt> receipts;

  @override
  State<_TrendsSection> createState() => _TrendsSectionState();
}

class _TrendsSectionState extends State<_TrendsSection> {
  TrendGranularity _granularity = TrendGranularity.month;
  ReceiptCategory? _category;
  DateTime _referenceDate = DateTime(DateTime.now().year, DateTime.now().month);

  String _bucketLabel(DateTime start) {
    switch (_granularity) {
      case TrendGranularity.day:
        return DateFormat.Md().format(start);
      case TrendGranularity.month:
        return DateFormat.MMM().format(start);
      case TrendGranularity.year:
        return DateFormat.y().format(start);
    }
  }

  void _shiftReferenceDate(int delta) {
    setState(() {
      switch (_granularity) {
        case TrendGranularity.day:
          _referenceDate = _referenceDate.add(Duration(days: delta));
        case TrendGranularity.month:
          _referenceDate = DateTime(
            _referenceDate.year,
            _referenceDate.month + delta,
          );
        case TrendGranularity.year:
          _referenceDate = DateTime(_referenceDate.year + delta);
      }
    });
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200) {
      _shiftReferenceDate(1);
    } else if (velocity > 200) {
      _shiftReferenceDate(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buckets = buildTrendBuckets(
      receipts: widget.receipts,
      granularity: _granularity,
      referenceDate: _referenceDate,
      category: _category,
    );
    final maxAmount = buckets.fold<int>(
      0,
      (max, b) => b.amountYen > max ? b.amountYen : max,
    );
    final barColor = _category != null
        ? categoryColors[_category]
        : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Trends', style: Theme.of(context).textTheme.titleSmall),
              Text(
                '${_bucketLabel(buckets.first.start)} – ${_bucketLabel(buckets.last.start)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<TrendGranularity>(
            segments: const [
              ButtonSegment(value: TrendGranularity.day, label: Text('Day')),
              ButtonSegment(
                value: TrendGranularity.month,
                label: Text('Month'),
              ),
              ButtonSegment(value: TrendGranularity.year, label: Text('Year')),
            ],
            selected: {_granularity},
            onSelectionChanged: (selection) =>
                setState(() => _granularity = selection.first),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final category in ReceiptCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Swipe here is scoped to just the bar chart, independent of the
          // donut's month and the outer category screen's swipe.
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: _onHorizontalSwipe,
              behavior: HitTestBehavior.translucent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final bucket in buckets)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          children: [
                            Text(
                              compactCurrencyFormat.format(bucket.amountYen),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            // Expanded + FractionallySizedBox sizes the bar
                            // from whatever space remains after the labels,
                            // so it can never overflow regardless of font
                            // scale or device.
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: maxAmount == 0
                                      ? 0.02
                                      : (bucket.amountYen / maxAmount).clamp(
                                          0.02,
                                          1.0,
                                        ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _bucketLabel(bucket.start),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
