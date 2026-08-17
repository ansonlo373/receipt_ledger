import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:receipt_ledger/data/receipt_repository.dart';
import 'package:receipt_ledger/data/receipts_database.dart';
import 'package:receipt_ledger/models/category_memory.dart';
import 'package:receipt_ledger/models/receipt_category.dart';
import 'package:receipt_ledger/models/receipt_ocr_result.dart';
import 'package:receipt_ledger/utils/formatters.dart';

class ReceiptFormScreen extends StatefulWidget {
  const ReceiptFormScreen({
    super.key,
    required this.repository,
    this.existing,
    this.initialPhotoPath,
    this.initialMerchant,
    this.initialAmountYen,
    this.initialAmountCandidates = const [],
    this.initialDate,
    this.ocrSource,
  });

  final ReceiptRepository repository;
  final Receipt? existing;

  /// A photo already captured before opening this screen (from the "Scan a
  /// receipt" flow). Ignored when [existing] is set — an edited receipt's
  /// photo comes from its own record instead.
  final String? initialPhotoPath;

  /// Fields guessed from the photo via OCR, all ignored when [existing] is
  /// set. Always editable — OCR is a starting point, not a commitment.
  final String? initialMerchant;
  final int? initialAmountYen;

  /// Every plausible ¥-marked amount OCR found, most-likely first. When this
  /// has more than one entry the amount is genuinely ambiguous — shown as
  /// quick-pick chips instead of trusting [initialAmountYen] alone.
  final List<int> initialAmountCandidates;

  final DateTime? initialDate;

  /// Which OCR pass produced the initial* fields, shown as a small badge so
  /// the user knows the data was guessed and should be double-checked. Null
  /// when there's nothing to badge (manual entry, or OCR found nothing).
  final OcrSource? ocrSource;

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
  late String? _photoPath;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _photoPath = existing?.photoPath ?? widget.initialPhotoPath;
    _merchantController = TextEditingController(
      text: existing?.merchant ?? widget.initialMerchant,
    );
    _amountController = TextEditingController(
      text: existing != null
          ? existing.amountYen.toString()
          : widget.initialAmountYen?.toString() ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes);
    _date = existing?.date ?? widget.initialDate ?? DateTime.now();
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
        photoPath: _photoPath,
      );
    } else {
      await widget.repository.update(
        id: existing.id,
        merchant: merchant,
        amountYen: amountYen,
        date: _date,
        category: _category,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        photoPath: _photoPath,
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
          photoPath: other.photoPath,
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
            if (_photoPath != null) ...[
              Stack(
                children: [
                  // BoxFit.contain (not cover) so a tall, narrow receipt is
                  // shown in full, letterboxed if needed, instead of having
                  // its top/bottom cropped to fill a fixed box — the saved
                  // file itself is never cropped either way.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: Container(
                        width: double.infinity,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Image.file(
                          File(_photoPath!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.white,
                        tooltip: 'Remove photo',
                        onPressed: () => setState(() => _photoPath = null),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.existing == null && widget.ocrSource != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '📱 ${widget.ocrSource!.label} — check the details below',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
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
            if (widget.existing == null &&
                widget.initialAmountCandidates.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OCR found more than one possible amount — pick one:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final candidate in widget.initialAmountCandidates)
                          ChoiceChip(
                            label: Text(currencyFormat.format(candidate)),
                            selected:
                                _amountController.text ==
                                candidate.toString(),
                            onSelected: (_) => setState(
                              () => _amountController.text = candidate
                                  .toString(),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
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
