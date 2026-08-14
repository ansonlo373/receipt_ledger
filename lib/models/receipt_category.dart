enum ReceiptCategory {
  groceries('Groceries'),
  dining('Dining'),
  transport('Transport'),
  utilities('Utilities'),
  shopping('Shopping'),
  other('Other');

  const ReceiptCategory(this.label);

  final String label;

  static ReceiptCategory fromName(String name) {
    return ReceiptCategory.values.firstWhere(
      (category) => category.name == name,
      orElse: () => ReceiptCategory.other,
    );
  }
}
