import 'dart:ui';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'logic/admins/admin_admins_cubit.dart';
import 'logic/auth/admin_auth_cubit.dart';
import 'logic/auth/admin_auth_state.dart';
import 'logic/courses/admin_courses_cubit.dart';
import 'logic/requests/admin_requests_cubit.dart';
import 'logic/students/admin_students_cubit.dart';
import 'screens/security/security_protection_watcher.dart';
import 'services/notification_service.dart';

/// جذر التطبيق. تُحقن التبعيات مرة واحدة في [State] بدل استدعاء `sl<>`
/// داخل `build` عند كل إعادة بناء.
class SecureAdminApp extends StatefulWidget {
  const SecureAdminApp({super.key});

  @override
  State<SecureAdminApp> createState() => _SecureAdminAppState();
}

class _SecureAdminAppState extends State<SecureAdminApp> {
  late final AdminAuthCubit _authCubit = sl<AdminAuthCubit>();
  late final GoRouter _router = sl<GoRouter>();

  @override
  void initState() {
    super.initState();
    if (_authCubit.state is AdminAuthenticated) {
      sl<AdminCoursesCubit>().loadCourses();
      sl<AdminStudentsCubit>().loadStudents();
      sl<AdminRequestsCubit>().loadRequests();
      sl<AdminAdminsCubit>().loadAdmins();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AdminAuthCubit>.value(value: _authCubit),
        BlocProvider<AdminAdminsCubit>.value(value: sl<AdminAdminsCubit>()),
        BlocProvider<AdminCoursesCubit>.value(value: sl<AdminCoursesCubit>()),
        BlocProvider<AdminStudentsCubit>.value(value: sl<AdminStudentsCubit>()),
        BlocProvider<AdminRequestsCubit>.value(value: sl<AdminRequestsCubit>()),
      ],
      child: MaterialApp.router(
        key: ValueKey(context.locale.languageCode),
        title: 'app_name'.tr(),
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: AppTheme.lightTheme,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        builder: (context, child) {
          return BlocListener<AdminAuthCubit, AdminAuthState>(
            listenWhen: (previous, current) =>
                current is AdminAuthenticated &&
                previous is! AdminAuthenticated,
            listener: (context, state) {
              if (state is AdminAuthenticated) {
                sl<AdminNotificationService>().syncAdminToken(state.user.uid);
                context.read<AdminCoursesCubit>().loadCourses();
                context.read<AdminStudentsCubit>().loadStudents();
                context.read<AdminRequestsCubit>().loadRequests();
                context.read<AdminAdminsCubit>().loadAdmins();
              }
            },
            // BlocSelector: لا يُعاد بناء الحارس الأمني إلا عند تغير هوية الأدمن.
            child: BlocSelector<AdminAuthCubit, AdminAuthState, _AdminIdentity>(
              selector: (state) => state is AdminAuthenticated
                  ? _AdminIdentity(state.user.uid, state.user.email)
                  : const _AdminIdentity(null, null),
              builder: (context, identity) {
                return AdminSecurityProtectionWatcher(
                  adminId: identity.uid,
                  adminEmail: identity.email,
                  child: child ?? const SizedBox.shrink(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

@immutable
class _AdminIdentity {
  final String? uid;
  final String? email;

  const _AdminIdentity(this.uid, this.email);

  @override
  bool operator ==(Object other) =>
      other is _AdminIdentity && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);
}

