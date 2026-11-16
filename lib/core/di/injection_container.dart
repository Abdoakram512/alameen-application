import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

// Services (Data Sources)
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/mux_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';

// Repositories (Interfaces & Implementations)
import '../../repositories/auth_repository.dart';
import '../../repositories/courses_repository.dart';
import '../../repositories/mux_repository.dart';
import '../../repositories/requests_repository.dart';
import '../../repositories/students_repository.dart';
import '../../repositories/impl/auth_repository_impl.dart';
import '../../repositories/impl/courses_repository_impl.dart';
import '../../repositories/impl/mux_repository_impl.dart';
import '../../repositories/impl/requests_repository_impl.dart';
import '../../repositories/impl/students_repository_impl.dart';

// ViewModels (Cubits)
import '../../logic/auth/admin_auth_cubit.dart';
import '../../logic/admins/admin_admins_cubit.dart';
import '../../logic/courses/admin_courses_cubit.dart';
import '../../logic/students/admin_students_cubit.dart';
import '../../logic/requests/admin_requests_cubit.dart';

// Routing
import '../routing/app_router.dart';

final sl = GetIt.instance; // sl = Service Locator

Future<void> initDependencies() async {
  // ---------------------------------------------------------------------------
  // 1. Data Sources & Services
  // ---------------------------------------------------------------------------
  sl.registerLazySingleton<AdminAuthService>(AdminAuthService.new);
  sl.registerLazySingleton<FirestoreService>(FirestoreService.new);
  sl.registerLazySingleton<MuxService>(MuxService.new);
  sl.registerLazySingleton<StorageService>(StorageService.new);
  sl.registerLazySingleton<AdminNotificationService>(AdminNotificationService.new);

  // ---------------------------------------------------------------------------
  // 2. Repositories (MVVM Data Layer: Interfaces -> Implementations)
  // ---------------------------------------------------------------------------
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(authService: sl<AdminAuthService>()),
  );

  sl.registerLazySingleton<CoursesRepository>(
    () => CoursesRepositoryImpl(firestoreService: sl<FirestoreService>()),
  );

  sl.registerLazySingleton<StudentsRepository>(
    () => StudentsRepositoryImpl(firestoreService: sl<FirestoreService>()),
  );

  sl.registerLazySingleton<RequestsRepository>(
    () => RequestsRepositoryImpl(firestoreService: sl<FirestoreService>()),
  );

  sl.registerLazySingleton<MuxRepository>(
    () => MuxRepositoryImpl(muxService: sl<MuxService>()),
  );

  // ---------------------------------------------------------------------------
  // 3. ViewModels (Cubits)
  // ---------------------------------------------------------------------------
  sl.registerLazySingleton<AdminAuthCubit>(
    () => AdminAuthCubit(authRepository: sl<AuthRepository>()),
  );

  sl.registerLazySingleton<AdminCoursesCubit>(
    () => AdminCoursesCubit(
      coursesRepository: sl<CoursesRepository>(),
      muxRepository: sl<MuxRepository>(),
    ),
  );

  sl.registerLazySingleton<AdminStudentsCubit>(
    () => AdminStudentsCubit(studentsRepository: sl<StudentsRepository>()),
  );

  sl.registerLazySingleton<AdminRequestsCubit>(
    () => AdminRequestsCubit(requestsRepository: sl<RequestsRepository>()),
  );

  sl.registerLazySingleton<AdminAdminsCubit>(
    () => AdminAdminsCubit(firestoreService: sl<FirestoreService>()),
  );

  // ---------------------------------------------------------------------------
  // 4. Routing (GoRouter)
  // ---------------------------------------------------------------------------
  sl.registerLazySingleton<GoRouter>(
    () => createAppRouter(sl<AdminAuthCubit>()),
  );
}
