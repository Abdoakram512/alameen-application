/// حالة المراجعة المالية لإيصال السداد في خادم Laravel.
/// هذه الحالة تصف سجل الإيصال المالي فقط، ولا تمنح أو تؤكد صلاحية الوصول للدورة.
enum ReceiptStatus {
  pending,
  approved,
  rejected;

  static ReceiptStatus fromApiValue(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return switch (normalized) {
      'approved' => ReceiptStatus.approved,
      'rejected' => ReceiptStatus.rejected,
      _ => ReceiptStatus.pending,
    };
  }
}
