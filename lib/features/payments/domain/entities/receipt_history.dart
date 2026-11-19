import 'package:equatable/equatable.dart';
import 'payment_receipt.dart';
import 'receipt_status.dart';

/// سجل إيصالات الدفع المجمع للعرض فقط (مرتباً من الأحدث إلى الأقدم).
/// لا يُستخدم لاتخاذ قرارات أهلية أو فتح دورات.
class ReceiptHistory extends Equatable {
  final List<PaymentReceipt> receipts;

  ReceiptHistory({
    required List<PaymentReceipt> receipts,
  }) : receipts = List.unmodifiable(
          List<PaymentReceipt>.from(receipts)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );

  static final empty = ReceiptHistory(receipts: const []);

  bool get isEmpty => receipts.isEmpty;
  bool get isNotEmpty => receipts.isNotEmpty;

  /// عدد الإيصالات قيد المراجعة أو المرفوضة التي تستدعي انتباه الطالب.
  int get activeActionableCount => receipts
      .where(
        (r) =>
            r.status == ReceiptStatus.pending ||
            r.status == ReceiptStatus.rejected,
      )
      .length;

  /// جميع الإيصالات الخاصة بدورة معينة (مرتبة زمنياً من الأحدث للأقدم).
  List<PaymentReceipt> forCourse(String courseId) {
    final target = courseId.trim();
    if (target.isEmpty) return const [];
    return List.unmodifiable(
      receipts.where(
        (r) => r.courseIdString == target || r.courseSlug == target,
      ),
    );
  }

  /// أحدث إيصال مالي مقدم للدورة بغرض العرض فقط (بدون خوارزمية أولوية approved > pending > rejected).
  PaymentReceipt? latestForCourse(String courseId) {
    final target = courseId.trim();
    if (target.isEmpty) return null;
    for (final receipt in receipts) {
      if (receipt.courseIdString == target || receipt.courseSlug == target) {
        return receipt;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [receipts];
}
