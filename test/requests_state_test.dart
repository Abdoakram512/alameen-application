import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_admin_app/logic/requests/admin_requests_cubit.dart';
import 'package:secure_admin_app/logic/requests/admin_requests_state.dart';
import 'package:secure_admin_app/models/access_request.dart';
import 'package:secure_admin_app/repositories/requests_repository.dart';
import 'test_localization_helper.dart';

class TestRequests implements RequestsRepository {
  // ignore: close_sinks
  final controller = StreamController<List<CourseAccessRequest>>.broadcast();
  Completer<void>? wait;
  bool fail = false;
  int approvals = 0;
  @override
  Stream<List<CourseAccessRequest>> streamRequests() => controller.stream;
  @override
  Stream<List<CourseAccessRequest>> streamStudentRequests(String id) =>
      controller.stream;
  @override
  Future<void> approveRequest(String id, String student, String course, {String? levelId}) async {
    approvals++;
    if (wait != null) await wait!.future;
    if (fail) throw Exception('offline');
  }

  @override
  Future<void> rejectRequest(String id, {String adminNotes = ''}) async {
    if (fail) throw Exception('offline');
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initTestLocalization(locale: const Locale('ar'));
  });

  late TestRequests repository;
  late AdminRequestsCubit cubit;
  setUp(() async {
    repository = TestRequests();
    cubit = AdminRequestsCubit(requestsRepository: repository);
    cubit.loadRequests();
    repository.controller.add([
      CourseAccessRequest(
        id: 'r',
        studentId: 's',
        studentName: 'طالب',
        studentEmail: 'test@example.test',
        courseId: 'c',
        courseTitle: 'كورس',
        requestedAt: DateTime(2026),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    await cubit.close();
    await repository.controller.close();
  });
  Future<void> approve() => cubit.approveRequest(
    requestId: 'r',
    studentId: 's',
    courseId: 'c',
    studentName: 'طالب',
  );
  test('Success retains the visible request list', () async {
    await approve();
    expect(cubit.state, isA<AdminRequestsActionSuccess>());
    expect((cubit.state as AdminRequestsLoaded).requests.single.id, 'r');
  });
  test(
    'Failed review retains data instead of showing an empty inbox',
    () async {
      repository.fail = true;
      await approve();
      expect(cubit.state, isA<AdminRequestsError>());
      expect((cubit.state as AdminRequestsLoaded).requests.length, 1);
    },
  );
  test('Double tap submits only one in-flight approval', () async {
    repository.wait = Completer<void>();
    final first = approve();
    await approve();
    expect(repository.approvals, 1);
    repository.wait!.complete();
    await first;
  });
}
