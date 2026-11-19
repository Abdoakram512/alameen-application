import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/features/payments/domain/entities/payment_method.dart';
import 'package:secure_screen_app/features/payments/domain/entities/receipt_status.dart';
import 'package:secure_screen_app/models/course.dart';
import 'package:secure_screen_app/models/payment_receipt_model.dart';

void main() {
  test('Approved payment receipt JSON deserializes cleanly to typed domain model', () {
    final receipt = PaymentReceiptModel.fromJson({
      'id': 1,
      'user_id': 10,
      'course_id': 5,
      'payment_method': 'instapay',
      'sender_identifier': 'ahmed@instapay',
      'amount_paid': 1500,
      'status': 'approved',
      'reviewed_at': '2026-11-06T08:00:00.000Z',
      'created_at': '2026-11-06T07:00:00.000Z',
    });
    expect(receipt.status, ReceiptStatus.approved);
    expect(receipt.paymentMethod, PaymentMethod.instapay);
    expect(receipt.reviewedAt!.toUtc(), DateTime.utc(2026, 11, 6, 8));
  });

  test('Rejection notes and status round trip accurately via JSON', () {
    final receipt = PaymentReceiptModel.fromJson({
      'id': 2,
      'user_id': 10,
      'course_id': 5,
      'payment_method': 'vodafone_cash',
      'sender_identifier': '01012345678',
      'amount_paid': 500,
      'status': 'rejected',
      'admin_notes': 'الإيصال غير واضح',
      'created_at': '2026-11-06T00:00:00.000Z',
    });
    final restored = PaymentReceiptModel.fromJson(receipt.toJson());
    expect(restored.status, ReceiptStatus.rejected);
    expect(restored.adminNotes, 'الإيصال غير واضح');
    expect(restored.userId, 10);
  });

  test('Admin course price and numeric count remain intact for student', () {
    final course = Course.fromMap({
      'id': 'c1',
      'title': 'أساسيات التخاطب',
      'price': 250,
      'enrolledCount': 3,
      'levels': [],
    });
    expect(course.price, 250);
    expect(course.enrolledCount, 3);
    expect(Course.fromMap(course.toMap()).price, 250);
  });
}
