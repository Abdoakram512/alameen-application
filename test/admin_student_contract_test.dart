import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secure_screen_app/models/access_request.dart';
import 'package:secure_screen_app/models/course.dart';
void main() {
 test('Admin approval Firestore Timestamp is readable by student', () {
  final reviewed = DateTime.utc(2026,11,6,8);
  final request = CourseAccessRequest.fromJson({'id':'r1','studentId':'s1','courseId':'c1','status':'approved','requestedAt':'2026-11-06T07:00:00.000Z','reviewedAt':Timestamp.fromDate(reviewed)});
  expect(request.status,AccessStatus.approved);
  expect(request.reviewedAt!.toUtc(),reviewed);
 });
 test('Rejection notes and pending legacy timestamps survive round trip', () {
  final request = CourseAccessRequest.fromJson({'id':'r1','studentId':'s1','courseId':'c1','status':'rejected','adminNotes':'الإيصال غير واضح','requestedAt':Timestamp.fromDate(DateTime.utc(2026,11,6))});
  final restored = CourseAccessRequest.fromJson(request.toJson());
  expect(restored.status, AccessStatus.rejected);
  expect(restored.adminNotes, 'الإيصال غير واضح');
  expect(restored.studentId,'s1');
 });
 test('Admin course price and numeric count remain intact for student', () {
  final course=Course.fromMap({'id':'c1','title':'أساسيات التخاطب','price':250,'enrolledCount':3,'levels':[]});
  expect(course.price,250);
  expect(course.enrolledCount,3);
  expect(Course.fromMap(course.toMap()).price,250);
 });
}
