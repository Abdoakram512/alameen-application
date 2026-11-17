import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../storage/course_local_cache.dart';
import '../storage/secure_token_storage.dart';
import '../../datasources/auth_remote_data_source.dart';
import '../../datasources/courses_remote_data_source.dart';
import '../../logic/access/access_cubit.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../repositories/impl/student_content_repository_impl.dart';
import '../../repositories/impl/student_courses_repository_impl.dart';
import '../../repositories/impl/student_profile_repository_impl.dart';
import '../../repositories/student_auth_repository.dart';
import '../../repositories/student_content_repository.dart';
import '../../repositories/student_courses_repository.dart';
import '../../repositories/student_learning_repository.dart';
import '../../repositories/student_profile_repository.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';

final sl = GetIt.instance; // Service Locator

Future<void> initDependencies() async {
  // 0. Core Network & Storage Layer (REST API Foundation)
  if (!sl.isRegistered<SecureTokenStorage>()) {
    sl.registerLazySingleton<SecureTokenStorage>(
      () => SecureTokenStorageImpl(),
    );
  }
  if (!sl.isRegistered<CourseLocalCache>()) {
    sl.registerLazySingleton<CourseLocalCache>(
      () => CourseLocalCacheImpl(),
    );
  }
  if (!sl.isRegistered<AuthInterceptor>()) {
    sl.registerLazySingleton<AuthInterceptor>(
      () => AuthInterceptor(
        tokenStorage: sl<SecureTokenStorage>(),
      ),
    );
  }
  if (!sl.isRegistered<ApiClient>()) {
    sl.registerLazySingleton<ApiClient>(
      () => ApiClient(
        authInterceptor: sl<AuthInterceptor>(),
      ),
    );
  }

  // 1. Remote Data Sources
  if (!sl.isRegistered<AuthRemoteDataSource>()) {
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
      ),
    );
  }
  if (!sl.isRegistered<CoursesRemoteDataSource>()) {
    sl.registerLazySingleton<CoursesRemoteDataSource>(
      () => CoursesRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
      ),
    );
  }

  // 2. Services
  if (!sl.isRegistered<AuthService>()) {
    sl.registerLazySingleton<AuthService>(() => AuthService());
  }
  if (!sl.isRegistered<FirestoreService>()) {
    sl.registerLazySingleton<FirestoreService>(() => FirestoreService());
  }
  if (!sl.isRegistered<StorageService>()) {
    sl.registerLazySingleton<StorageService>(() => StorageService());
  }
  if (!sl.isRegistered<NotificationService>()) {
    sl.registerLazySingleton<NotificationService>(() => NotificationService());
  }

  // 3. Repositories
  if (!sl.isRegistered<StudentAuthRepository>()) {
    sl.registerLazySingleton<StudentAuthRepository>(
      () => StudentAuthRepositoryImpl(
        remoteDataSource: sl<AuthRemoteDataSource>(),
        tokenStorage: sl<SecureTokenStorage>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentCoursesRepository>()) {
    sl.registerLazySingleton<StudentCoursesRepository>(
      () => StudentCoursesRepositoryImpl(
        remoteDataSource: sl<CoursesRemoteDataSource>(),
        localCache: sl<CourseLocalCache>(),
        tokenStorage: sl<SecureTokenStorage>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentProfileRepository>()) {
    sl.registerLazySingleton<StudentProfileRepository>(
      () => StudentProfileRepositoryImpl(
        authRemoteDataSource: sl<AuthRemoteDataSource>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentContentRepository>()) {
    sl.registerLazySingleton<StudentContentRepository>(
      () => StudentContentRepositoryImpl(
        coursesRemoteDataSource: sl<CoursesRemoteDataSource>(),
        localCache: sl<CourseLocalCache>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentLearningRepository>()) {
    sl.registerLazySingleton<StudentLearningRepository>(
      () => StudentLearningRepositoryImpl(
        firestoreService: sl<FirestoreService>(),
        storageService: sl<StorageService>(),
      ),
    );
  }

  // 4. Cubits
  if (!sl.isRegistered<AuthCubit>()) {
    sl.registerFactory<AuthCubit>(
      () => AuthCubit(
        authRepository: sl<StudentAuthRepository>(),
        profileRepository: sl<StudentProfileRepository>(),
        firestoreService: sl<FirestoreService>(),
      ),
    );
  }

  if (!sl.isRegistered<CoursesCubit>()) {
    sl.registerFactory<CoursesCubit>(
      () => CoursesCubit(
        coursesRepository: sl<StudentCoursesRepository>(),
        firestoreService: sl<FirestoreService>(),
      ),
    );
  }

  if (!sl.isRegistered<AccessCubit>()) {
    sl.registerFactory<AccessCubit>(
      () => AccessCubit(
        firestoreService: sl<FirestoreService>(),
        storageService: sl<StorageService>(),
      ),
    );
  }
}
