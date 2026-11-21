import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection_container.dart';
import '../features/courses/presentation/cubits/course_entitlement/course_entitlement_cubit.dart';
import '../features/payments/presentation/cubits/receipts/receipts_cubit.dart';
import '../logic/auth/auth_cubit.dart';
import '../logic/auth/auth_state.dart';
import '../logic/courses/courses_cubit.dart';

/// نطاق ميزات الطالب المشتركة (Lazy on-demand scoped provider)
/// يضمن:
/// 1. عدم استدعاء أو إنشاء الكيوبت في main.dart قبل حاجة الشاشات إليه (Lazy Loading).
/// 2. عدم إغلاق الكيوبت أو فقدان الـ state عند الخروج من الشاشات بفضل BlocProvider.value (State Persistence).
class StudentFeatureScope extends StatefulWidget {
  final Widget child;

  const StudentFeatureScope({super.key, required this.child});

  @override
  State<StudentFeatureScope> createState() => _StudentFeatureScopeState();
}

class _StudentFeatureScopeState extends State<StudentFeatureScope> {
  late final CoursesCubit _coursesCubit;
  late final ReceiptsCubit _receiptsCubit;
  late final CourseEntitlementCubit _courseEntitlementCubit;
  StreamSubscription<AuthState>? _authSubscription;
  String? _lastSyncedUid;

  @override
  void initState() {
    super.initState();
    _coursesCubit = sl<CoursesCubit>();
    _receiptsCubit = sl<ReceiptsCubit>();
    _courseEntitlementCubit = sl<CourseEntitlementCubit>();

    final authCubit = sl<AuthCubit>();
    _syncSession(authCubit.state);
    _authSubscription = authCubit.stream.listen(_syncSession);
  }

  void _syncSession(AuthState state) {
    if (state is Authenticated) {
      final uid = state.user.uid;
      if (_lastSyncedUid != uid) {
        if (_lastSyncedUid != null) {
          _coursesCubit.clearStudentSession();
        }
        _lastSyncedUid = uid;
        unawaited(
          _courseEntitlementCubit.syncStudentEnrollments(studentId: uid),
        );
      }
    } else if (state is Unauthenticated ||
        state is AuthSuspended ||
        state is AuthPendingApproval) {
      _lastSyncedUid = null;
      _courseEntitlementCubit.clear();
      _coursesCubit.clearStudentSession();
      _receiptsCubit.clear();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CoursesCubit>.value(value: _coursesCubit),
        BlocProvider<ReceiptsCubit>.value(value: _receiptsCubit),
        BlocProvider<CourseEntitlementCubit>.value(
          value: _courseEntitlementCubit,
        ),
      ],
      child: widget.child,
    );
  }
}
