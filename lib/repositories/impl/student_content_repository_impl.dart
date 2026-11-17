import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/di/injection_container.dart';
import '../../core/storage/course_local_cache.dart';
import '../../datasources/courses_remote_data_source.dart';
import '../../models/bootstrap_data.dart';
import '../../models/contact_info_data.dart';
import '../student_content_repository.dart';

class StudentContentRepositoryImpl implements StudentContentRepository {
  final CoursesRemoteDataSource? _explicitCoursesRemoteDataSource;
  final CourseLocalCache? _explicitLocalCache;
  final FirebaseFirestore? _explicitFirestore;

  StudentContentRepositoryImpl({
    CoursesRemoteDataSource? coursesRemoteDataSource,
    CourseLocalCache? localCache,
    FirebaseFirestore? firestore,
  })  : _explicitCoursesRemoteDataSource = coursesRemoteDataSource,
        _explicitLocalCache = localCache,
        _explicitFirestore = firestore;

  CoursesRemoteDataSource? get _remote {
    if (_explicitCoursesRemoteDataSource != null) return _explicitCoursesRemoteDataSource;
    if (sl.isRegistered<CoursesRemoteDataSource>()) {
      return sl<CoursesRemoteDataSource>();
    }
    return null;
  }

  CourseLocalCache get _cache {
    if (_explicitLocalCache != null) return _explicitLocalCache;
    if (sl.isRegistered<CourseLocalCache>()) {
      return sl<CourseLocalCache>();
    }
    return CourseLocalCacheImpl();
  }

  bool get isAvailable {
    try {
      final _ = db;
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get db => _explicitFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _appContentRef =>
      db.collection('app_content');

  // Legacy app content stream for unmigrated features
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAppContent(String docId) {
    if (!isAvailable) return const Stream.empty();
    return _appContentRef.doc(docId).snapshots();
  }

  @override
  Future<Map<String, dynamic>?> getAppContent(String docId) async {
    if (!isAvailable) return null;
    try {
      final doc = await _appContentRef.doc(docId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // P3 REST API + LOCAL CACHE IMPLEMENTATIONS
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<BootstrapData?> getBootstrapConfig() async {
    final remote = _remote;
    if (remote != null) {
      try {
        final bootstrap = await remote.getBootstrapConfig();
        await _cache.saveBootstrap(bootstrap);
        return bootstrap;
      } catch (_) {
        return await _cache.getBootstrap();
      }
    }
    return await _cache.getBootstrap();
  }

  @override
  Future<Map<String, dynamic>?> getLandingPageData() async {
    final remote = _remote;
    if (remote != null) {
      try {
        return await remote.getLandingPageData();
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<ContactInfoData?> getContactInfo() async {
    final remote = _remote;
    if (remote != null) {
      try {
        final contact = await remote.getContactInfo();
        await _cache.saveContactInfo(contact);
        return contact;
      } catch (_) {
        return await _cache.getContactInfo();
      }
    }
    return await _cache.getContactInfo();
  }
}
