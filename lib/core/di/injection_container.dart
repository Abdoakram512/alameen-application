import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../storage/course_local_cache.dart';
import '../storage/secure_token_storage.dart';
import '../../datasources/assignments_remote_data_source.dart';
import '../../datasources/auth_remote_data_source.dart';
import '../../datasources/certificates_remote_data_source.dart';
import '../../datasources/courses_remote_data_source.dart';
import '../../datasources/notifications_remote_data_source.dart';
import '../../datasources/payment_remote_data_source.dart';
import '../../datasources/support_tickets_remote_data_source.dart';
import '../../datasources/watch_remote_data_source.dart';
import '../../logic/access/access_cubit.dart';
import '../../logic/assignments/assignments_cubit.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/certificates/certificates_cubit.dart';
import '../../logic/content/content_cubit.dart';
import '../../logic/courses/courses_cubit.dart';
import '../../logic/notifications/notifications_cubit.dart';
import '../../logic/support/support_tickets_cubit.dart';
import '../../logic/support/ticket_conversation_cubit.dart';
import '../../repositories/impl/student_assignments_repository_impl.dart';
import '../../repositories/impl/student_content_repository_impl.dart';
import '../../repositories/impl/student_courses_repository_impl.dart';
import '../../repositories/impl/student_notifications_repository_impl.dart';
import '../../repositories/impl/student_payment_repository_impl.dart';
import '../../repositories/impl/student_profile_repository_impl.dart';
import '../../repositories/impl/student_support_repository_impl.dart';
import '../../repositories/impl/student_watch_repository_impl.dart';
import '../../repositories/student_assignments_repository.dart';
import '../../repositories/student_auth_repository.dart';
import '../../repositories/student_certificates_repository.dart';
import '../../repositories/student_content_repository.dart';
import '../../repositories/student_courses_repository.dart';
import '../../repositories/student_learning_repository.dart';
import '../../repositories/student_notifications_repository.dart';
import '../../repositories/student_payment_repository.dart';
import '../../repositories/student_profile_repository.dart';
import '../../repositories/student_support_repository.dart';
import '../../repositories/student_watch_repository.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/watch_queue.dart';

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
  if (!sl.isRegistered<PaymentRemoteDataSource>()) {
    sl.registerLazySingleton<PaymentRemoteDataSource>(
      () => PaymentRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
      ),
    );
  }
  if (!sl.isRegistered<WatchRemoteDataSource>()) {
    sl.registerLazySingleton<WatchRemoteDataSource>(
      () => WatchRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
      ),
    );
  }
  if (!sl.isRegistered<AssignmentsRemoteDataSource>()) {
    sl.registerLazySingleton<AssignmentsRemoteDataSource>(
      () => AssignmentsRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
      ),
    );
  }
  if (!sl.isRegistered<CertificatesRemoteDataSource>()) {
    sl.registerLazySingleton<CertificatesRemoteDataSource>(
      () => CertificatesRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
      ),
    );
  }
  if (!sl.isRegistered<NotificationsRemoteDataSource>()) {
    sl.registerLazySingleton<NotificationsRemoteDataSource>(
      () => NotificationsRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
      ),
    );
  }
  if (!sl.isRegistered<SupportTicketsRemoteDataSource>()) {
    sl.registerLazySingleton<SupportTicketsRemoteDataSource>(
      () => SupportTicketsRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
      ),
    );
  }

  // 2. Services
  if (!sl.isRegistered<AuthService>()) {
    sl.registerLazySingleton<AuthService>(() => AuthService());
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
  if (!sl.isRegistered<StudentWatchRepository>()) {
    sl.registerLazySingleton<StudentWatchRepository>(
      () => StudentWatchRepositoryImpl(
        remoteDataSource: sl<WatchRemoteDataSource>(),
      ),
    );
  }
  if (!sl.isRegistered<WatchQueue>()) {
    sl.registerLazySingleton<WatchQueue>(
      () => WatchQueue.forRepository(sl<StudentWatchRepository>()),
    );
  }
  if (!sl.isRegistered<StudentAssignmentsRepository>()) {
    sl.registerLazySingleton<StudentAssignmentsRepository>(
      () => StudentAssignmentsRepositoryImpl(
        remoteDataSource: sl<AssignmentsRemoteDataSource>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentCertificatesRepository>()) {
    sl.registerLazySingleton<StudentCertificatesRepository>(
      () => StudentCertificatesRepositoryImpl(
        remoteDataSource: sl<CertificatesRemoteDataSource>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentLearningRepository>()) {
    sl.registerLazySingleton<StudentLearningRepository>(
      () => StudentLearningRepositoryImpl(
        assignmentsRepository: sl<StudentAssignmentsRepository>(),
        watchRepository: sl<StudentWatchRepository>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentPaymentRepository>()) {
    sl.registerLazySingleton<StudentPaymentRepository>(
      () => StudentPaymentRepositoryImpl(
        remoteDataSource: sl<PaymentRemoteDataSource>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentNotificationsRepository>()) {
    sl.registerLazySingleton<StudentNotificationsRepository>(
      () => StudentNotificationsRepositoryImpl(
        remoteDataSource: sl<NotificationsRemoteDataSource>(),
      ),
    );
  }
  if (!sl.isRegistered<StudentSupportRepository>()) {
    sl.registerLazySingleton<StudentSupportRepository>(
      () => StudentSupportRepositoryImpl(
        remoteDataSource: sl<SupportTicketsRemoteDataSource>(),
      ),
    );
  }

  // 4. Cubits
  if (!sl.isRegistered<AuthCubit>()) {
    sl.registerFactory<AuthCubit>(
      () => AuthCubit(
        authRepository: sl<StudentAuthRepository>(),
        profileRepository: sl<StudentProfileRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<CoursesCubit>()) {
    sl.registerFactory<CoursesCubit>(
      () => CoursesCubit(
        coursesRepository: sl<StudentCoursesRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<AccessCubit>()) {
    sl.registerFactory<AccessCubit>(
      () => AccessCubit(
        paymentRepository: sl<StudentPaymentRepository>(),
        coursesRepository: sl<StudentCoursesRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<NotificationsCubit>()) {
    sl.registerFactory<NotificationsCubit>(
      () => NotificationsCubit(
        repository: sl<StudentNotificationsRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<SupportTicketsCubit>()) {
    sl.registerFactory<SupportTicketsCubit>(
      () => SupportTicketsCubit(
        repository: sl<StudentSupportRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<TicketConversationCubit>()) {
    sl.registerFactoryParam<TicketConversationCubit, int, void>(
      (ticketId, _) => TicketConversationCubit(
        repository: sl<StudentSupportRepository>(),
        ticketId: ticketId,
      ),
    );
  }

  if (!sl.isRegistered<CertificatesCubit>()) {
    sl.registerFactory<CertificatesCubit>(
      () => CertificatesCubit(
        repository: sl<StudentCertificatesRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<AssignmentsCubit>()) {
    sl.registerFactory<AssignmentsCubit>(
      () => AssignmentsCubit(
        repository: sl<StudentAssignmentsRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<ContentCubit>()) {
    sl.registerFactory<ContentCubit>(
      () => ContentCubit(
        repository: sl<StudentContentRepository>(),
      ),
    );
  }
}
