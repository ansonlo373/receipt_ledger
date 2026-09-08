import 'package:flutter/material.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/models/receipt.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/models/receipt_filter.dart';
import 'package:receipt_ledger/screens/filter_screen.dart';
import 'package:receipt_ledger/screens/receipt_form_screen.dart';
import 'package:receipt_ledger/screens/trash_screen.dart';
import 'package:receipt_ledger/services/photo_sync_service.dart';
import 'package:receipt_ledger/utils/formatters.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({
    super.key,
    required this.repository,
    required this.photoSyncService,
  });

  final ReceiptRepository repository;

  /// Passed straight through to the edit form, which needs it to upload or
  /// delete a photo when the receipt is saved.
  final PhotoSyncService photoSyncService;

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  String _searchQuery = '';
  ReceiptFilter _filter = const ReceiptFilter();
  bool _newestFirst = true;
  final Set<String> _selectedIds = {};

  bool get _isSelecting => _selectedIds.isNotEmpty;

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _deleteSelected() async {
    final ids = List.of(_selectedIds);
    setState(_selectedIds.clear);
    for (final id in ids) {
      await widget.repository.softDelete(id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1
                ? 'Receipt moved to Trash'
                : '${ids.length} receipts moved to Trash',
          ),
        ),
      );
    }
  }

  void _openManualEntry({Receipt? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReceiptFormScreen(
          repository: widget.repository,
          photoSyncService: widget.photoSyncService,
          existing: existing,
        ),
      ),
    );
  }

  void _openTrash() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrashScreen(repository: widget.repository),
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await Navigator.of(context).push<ReceiptFilter>(
      MaterialPageRoute(
        builder: (context) => FilterScreen(initialFilter: _filter),
      ),
    );
    if (result != null) setState(() => _filter = result);
  }

  List<Receipt> _applyFiltersAndSort(List<Receipt> receipts) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = receipts.where((r) {
      if (query.isNotEmpty && !r.merchant.toLowerCase().contains(query)) {
        return false;
      }
      return _filter.matches(r);
    }).toList();

    filtered.sort(
      (a, b) =>
          _newestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
    );
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete selected',
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('Receipts'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Trash',
                  onPressed: _openTrash,
                ),
              ],
            ),
      body: StreamBuilder<List<Receipt>>(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          final allReceipts = snapshot.data ?? const [];
          final receipts = _applyFiltersAndSort(allReceipts);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search merchant…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _filter.dateRange == null
                        ? 'All time'
                        : '${dateFormat.format(_filter.dateRange!.start)} – '
                              '${dateFormat.format(_filter.dateRange!.end)}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filter.categories.isEmpty,
                        onSelected: (_) => setState(
                          () => _filter = _filter.copyWith(categories: {}),
                        ),
                      ),
                    ),
                    for (final category in ReceiptCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(category.label),
                          selected: _filter.categories.contains(category),
                          onSelected: (_) => setState(
                            () => _filter = _filter.copyWith(
                              categories: {category},
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
                      icon: Icon(
                        _newestFirst
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                      onPressed: () =>
                          setState(() => _newestFirst = !_newestFirst),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: receipts.isEmpty
                    ? const Center(child: Text('No receipts yet'))
                    : ListView.builder(
                        itemCount: receipts.length,
                        itemBuilder: (context, index) {
                          final receipt = receipts[index];
                          final selected = _selectedIds.contains(receipt.id);
                          return ListTile(
                            leading: _isSelecting
                                ? Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  )
                                : null,
                            selected: selected,
                            title: Text(receipt.merchant),
                            subtitle: Text(
                              '${dateFormat.format(receipt.date)} · '
                              '${ReceiptCategory.fromName(receipt.category).label}',
                            ),
                            trailing: Text(
                              currencyFormat.format(receipt.amountYen),
                            ),
                            onTap: () => _isSelecting
                                ? _toggleSelected(receipt.id)
                                : _openManualEntry(existing: receipt),
                            onLongPress: () => _toggleSelected(receipt.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
              onPressed: () => _openManualEntry(),
              child: const Icon(Icons.add),
            ),
    );
  }
}
