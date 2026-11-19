/// وسائل الدفع الإلكتروني المعتمدة في عقد Laravel OpenAPI.
enum PaymentMethod {
  vodafoneCash('vodafone_cash', 'فودافون كاش (Vodafone Cash)'),
  instapay('instapay', 'إنستاباي (InstaPay)');

  final String apiValue;
  final String displayLabelAr;

  const PaymentMethod(this.apiValue, this.displayLabelAr);

  /// تحليل صارم لوسيلة الدفع دون افتراض قيمة صامتة عند القيم غير المعروفة.
  static PaymentMethod? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    if (normalized == 'vodafone_cash' ||
        normalized == 'vodafone cash' ||
        normalized == 'فودافون كاش' ||
        normalized.contains('فودافون') ||
        normalized.contains('vodafone')) {
      return PaymentMethod.vodafoneCash;
    }

    if (normalized == 'instapay' ||
        normalized == 'insta pay' ||
        normalized == 'إنستاباي' ||
        normalized == 'انستاباي' ||
        normalized.contains('instapay') ||
        normalized.contains('إنستا') ||
        normalized.contains('انستا')) {
      return PaymentMethod.instapay;
    }

    return null;
  }
}
