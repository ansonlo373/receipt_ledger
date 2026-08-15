import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/category_memory.dart';
import 'package:receipt_ledger/models/receipt_category.dart';

class ReceiptFormScreen extends StatefulWidget {
  const ReceiptFormScreen({super.key, required this.repository, this.existing});

  final ReceiptRepository repository;
  final Receipt? existing;

  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late DateTime _date;
  late ReceiptCategory _category;
  bool _categoryManuallySet = false;
  List<Receipt> _allReceipts = const [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _merchantController = TextEditingController(text: existing?.merchant);
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amountYen.toString(),
    );
    _notesController = TextEditingController(text: existing?.notes);
    _date = existing?.date ?? DateTime.now();
    _category = existing == null
        ? ReceiptCategory.other
        : ReceiptCategory.fromName(existing.category);

    widget.repository.watchAll().first.then((receipts) {
      if (!mounted) return;
      setState(() => _allReceipts = receipts);
      // Only new (non-edit) receipts get a category suggested from merchant
      // history — an existing receipt's category is already an explicit
      // choice and shouldn't be silently overwritten.
      if (existing == null) _applyRememberedCategory();
    });
  }

  void _applyRememberedCategory() {
    if (_categoryManuallySet) return;
    final suggestion = rememberedCategoryFor(
      _allReceipts,
      _merchantController.text,
    );
    if (suggestion != null && suggestion != _category) {
      setState(() => _category = suggestion);
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amountYen = int.parse(_amountController.text);
    final existing = widget.existing;
    final merchant = _merchantController.text;

    // Does saving with _category disagree with what this merchant's other
    // receipts already use? For an edit, "already use" means this receipt's
    // own prior category; for a new receipt, it means whatever category is
    // remembered for the merchant. Either way, offer to bring the rest of
    // that merchant's receipts in line rather than leaving them mismatched.
    final priorCategory = existing == null
        ? rememberedCategoryFor(_allReceipts, merchant)
        : ReceiptCategory.fromName(existing.category);
    final categoryChanged = priorCategory != null && priorCategory != _category;
    final others = categoryChanged
        ? otherReceiptsForMerchant(_allReceipts, merchant, existing?.id ?? -1)
        : const <Receipt>[];

    var updateOthersToo = false;
    if (others.isNotEmpty) {
      final choice = await _confirmBulkCategoryUpdate(others.length);
      if (choice == null) return; // dialog dismissed, keep editing
      updateOthersToo = choice;
    }

    if (existing == null) {
      await widget.repository.add(
        merchant: merchant,
        amountYen: amountYen,
        date: _date,
        category: _category,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
    } else {
      await widget.repository.update(
        id: existing.id,
        merchant: merchant,
        amountYen: amountYen,
        date: _date,
        category: _category,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
    }

    if (updateOthersToo) {
      for (final other in others) {
        await widget.repository.update(
          id: other.id,
          merchant: other.merchant,
          amountYen: other.amountYen,
          date: other.date,
          category: _category,
          notes: other.notes,
        );
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<bool?> _confirmBulkCategoryUpdate(int otherCount) {
    final merchant = _merchantController.text.trim();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update other receipts too?'),
        content: Text(
          'Change the category to "${_category.label}" for the other '
          '$otherCount receipt${otherCount == 1 ? '' : 's'} from $merchant '
          'as well?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Just this one'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update all'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add receipt' : 'Edit receipt'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(labelText: 'Merchant'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a merchant'
                  : null,
              onChanged: widget.existing == null
                  ? (_) => _applyRememberedCategory()
                  : null,
            ),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (¥)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter an amount greater than 0';
                }
                return null;
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              onTap: _pickDate,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Category',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final category in ReceiptCategory.values)
                  ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() {
                      _category = category;
                      _categoryManuallySet = true;
                    }),
                  ),
              ],
            ),
            if (widget.existing == null &&
                !_categoryManuallySet &&
                rememberedCategoryFor(
                      _allReceipts,
                      _merchantController.text,
                    ) ==
                    _category &&
                _merchantController.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Remembered from ${_merchantController.text.trim()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
