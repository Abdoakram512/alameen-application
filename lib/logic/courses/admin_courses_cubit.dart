import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/network_error_mapper.dart';
import '../../models/assignment.dart';
import '../../models/course.dart';
import '../../models/course_access_mode.dart';
import '../../models/course_level.dart';
import '../../models/lesson.dart';
import '../../repositories/courses_repository.dart';
import '../../repositories/impl/courses_repository_impl.dart';
import '../../repositories/mux_repository.dart';
import '../../repositories/impl/mux_repository_impl.dart';
import 'admin_courses_state.dart';

class AdminCoursesCubit extends Cubit<AdminCoursesState> {
  final CoursesRepository _coursesRepository;
  final MuxRepository _muxRepository;
  StreamSubscription? _coursesSubscription;
  List<Course> _currentCourses = [];

  Timer? _processingSyncTimer;
  bool _isSyncingLessons = false;

  AdminCoursesCubit({
    CoursesRepository? coursesRepository,
    MuxRepository? muxRepository,
  })  : _coursesRepository = coursesRepository ?? CoursesRepositoryImpl(),
        _muxRepository = muxRepository ?? MuxRepositoryImpl(),
        super(const AdminCoursesLoading());

  void loadCourses() {
    if (state is! AdminCoursesLoading && _currentCourses.isEmpty) {
      emit(const AdminCoursesLoading());
    }
    _coursesSubscription?.cancel();
    _coursesSubscription = _coursesRepository.streamCourses().listen(
      (courses) {
        _currentCourses = courses;
        emit(AdminCoursesLoaded(courses));
        final hasProcessing = courses.any((c) =>
            c.levels.any((l) => l.lessons.any((les) => les.isVideoProcessing)));
        if (hasProcessing) {
          _scheduleProcessingLessonsSync();
        } else {
          _processingSyncTimer?.cancel();
          _processingSyncTimer = null;
        }
      },
      onError: (e) {
        emit(
          AdminCoursesError(
            NetworkErrorMapper.toArabicMessage(
              e,
              defaultMessage: 'تعذر تحميل بيانات الكورسات من الخادم.',
            ),
            _currentCourses,
          ),
        );
      },
    );
  }

  void _scheduleProcessingLessonsSync() {
    if (_processingSyncTimer != null && _processingSyncTimer!.isActive) return;
    _processingSyncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(syncAllProcessingLessons());
    });
  }

  List<Course> get currentCourses => _currentCourses;

  Future<bool> addCourse(Course course) async {
    final rollback = List<Course>.from(_currentCourses);
    // Optimistic update
    final courseId = course.id.trim().isNotEmpty
        ? course.id.trim()
        : 'c_${DateTime.now().millisecondsSinceEpoch}';
    final readyCourse = course.copyWith(id: courseId);
    _currentCourses = List<Course>.from(_currentCourses)..add(readyCourse);
    emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));

    try {
      await _coursesRepository.saveCourse(readyCourse);
      if (!isClosed) {
        emit(
          AdminCoursesActionSuccess(
            'تم حفظ الكورس بنجاح في سنتر الأمين!',
            List<Course>.from(_currentCourses),
          ),
        );
      }
      return true;
    } catch (e) {
      _currentCourses = rollback;
      if (!isClosed) {
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        emit(AdminCoursesError('فشل حفظ الكورس: $e', _currentCourses));
      }
      return false;
    }
  }

  Future<bool> updateCourse(Course course) async {
    final rollback = List<Course>.from(_currentCourses);
    final idx = _currentCourses.indexWhere((c) => c.id == course.id);
    if (idx != -1) {
      _currentCourses = List<Course>.from(_currentCourses);
      _currentCourses[idx] = course;
      emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
    }

    try {
      await _coursesRepository.saveCourse(course);
      if (!isClosed) {
        emit(
          AdminCoursesActionSuccess(
            'تم تحديث بيانات وسعر الكورس بنجاح!',
            List<Course>.from(_currentCourses),
          ),
        );
      }
      return true;
    } catch (e) {
      _currentCourses = rollback;
      if (!isClosed) {
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        emit(AdminCoursesError('فشل تعديل الكورس: $e', _currentCourses));
      }
      return false;
    }
  }

  Future<void> deleteCourse(String courseId) async {
    final rollback = List<Course>.from(_currentCourses);
    _currentCourses = _currentCourses.where((c) => c.id != courseId).toList();
    emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));

    try {
      await _coursesRepository.deleteCourse(courseId);
      if (!isClosed) {
        emit(AdminCoursesActionSuccess('تم حذف الكورس بنجاح.', List<Course>.from(_currentCourses)));
      }
    } catch (e) {
      _currentCourses = rollback;
      if (!isClosed) {
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        emit(AdminCoursesError('فشل حذف الكورس: $e', _currentCourses));
      }
    }
  }

  Future<bool> addLevel(String courseId, CourseLevel level) async {
    final rollback = List<Course>.from(_currentCourses);
    final courseIdx = _currentCourses.indexWhere((c) => c.id == courseId);
    if (courseIdx != -1) {
      final c = _currentCourses[courseIdx];
      final updatedLevels = List<CourseLevel>.from(c.levels)..add(level);
      updatedLevels.sort((a, b) => a.order.compareTo(b.order));
      for (int i = 0; i < updatedLevels.length; i++) {
        updatedLevels[i] = updatedLevels[i].copyWith(order: i + 1);
      }
      _currentCourses = List<Course>.from(_currentCourses);
      _currentCourses[courseIdx] = c.copyWith(levels: updatedLevels);
      emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
    }

    try {
      await _coursesRepository.addLevelToCourse(courseId, level);
      if (!isClosed) {
        emit(
          AdminCoursesActionSuccess('تم إضافة المستوى بنجاح.', List<Course>.from(_currentCourses)),
        );
      }
      return true;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        if (!isClosed) {
          emit(
            AdminCoursesActionSuccess('تم حفظ المستوى محلياً وجاري مزامنته مع الخادم.', List<Course>.from(_currentCourses)),
          );
        }
        return true;
      }
      _currentCourses = rollback;
      if (!isClosed) {
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        emit(AdminCoursesError('فشل إضافة المستوى: $e', _currentCourses));
      }
      return false;
    }
  }

  Future<void> deleteLevel(String courseId, String levelId) async {
    final rollback = List<Course>.from(_currentCourses);
    final courseIdx = _currentCourses.indexWhere((c) => c.id == courseId);
    if (courseIdx != -1) {
      final c = _currentCourses[courseIdx];
      final updatedLevels = c.levels.where((l) => l.id != levelId).toList();
      for (int i = 0; i < updatedLevels.length; i++) {
        updatedLevels[i] = updatedLevels[i].copyWith(order: i + 1);
      }
      _currentCourses = List<Course>.from(_currentCourses);
      _currentCourses[courseIdx] = c.copyWith(levels: updatedLevels);
      emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
    }

    try {
      await _coursesRepository.deleteLevelFromCourse(courseId, levelId);
      if (!isClosed) {
        emit(AdminCoursesActionSuccess('تم حذف المستوى بنجاح.', List<Course>.from(_currentCourses)));
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        if (!isClosed) {
          emit(AdminCoursesActionSuccess('تم حذف المستوى بنجاح وجاري مزامنته مع الخادم.', List<Course>.from(_currentCourses)));
        }
        return;
      }
      _currentCourses = rollback;
      if (!isClosed) {
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        emit(AdminCoursesError('فشل حذف المستوى: $e', _currentCourses));
      }
    }
  }

  Future<bool> addLesson(
    String courseId,
    String levelId,
    Lesson lesson, {
    Assignment? assignment,
  }) async {
    final rollback = List<Course>.from(_currentCourses);
    final courseIdx = _currentCourses.indexWhere((c) => c.id == courseId);
    if (courseIdx != -1) {
      final c = _currentCourses[courseIdx];
      final lvlIdx = c.levels.indexWhere((l) => l.id == levelId);
      if (lvlIdx != -1) {
        final targetLvl = c.levels[lvlIdx];
        final nextOrder = targetLvl.lessons.length + 1;
        final orderedLesson = lesson.copyWith(order: nextOrder);
        final updatedLessons = List<Lesson>.from(targetLvl.lessons)..add(orderedLesson);
        updatedLessons.sort((a, b) => a.order.compareTo(b.order));
        final updatedLvl = targetLvl.copyWith(lessons: updatedLessons);
        final updatedLvls = List<CourseLevel>.from(c.levels);
        updatedLvls[lvlIdx] = updatedLvl;
        _currentCourses = List<Course>.from(_currentCourses);
        _currentCourses[courseIdx] = c.copyWith(levels: updatedLvls);
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
      }
    }

    try {
      await _coursesRepository.addLessonToLevel(
        courseId,
        levelId,
        lesson,
        assignment: assignment,
      );
      if (!isClosed) {
        emit(
          AdminCoursesActionSuccess(
            'تم إضافة الدرس بنجاح للمستوى!',
            List<Course>.from(_currentCourses),
          ),
        );
      }
      return true;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        if (!isClosed) {
          emit(
            AdminCoursesActionSuccess(
              'تم حفظ الدرس محلياً وجاري مزامنته مع الخادم.',
              List<Course>.from(_currentCourses),
            ),
          );
        }
        return true;
      }
      _currentCourses = rollback;
      if (!isClosed) {
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        emit(AdminCoursesError('فشل إضافة الدرس: $e', _currentCourses));
      }
      return false;
    }
  }

  Future<void> deleteLesson(
    String courseId,
    String levelId,
    String lessonId,
  ) async {
    final rollback = List<Course>.from(_currentCourses);
    final courseIdx = _currentCourses.indexWhere((c) => c.id == courseId);
    if (courseIdx != -1) {
      final c = _currentCourses[courseIdx];
      final lvlIdx = c.levels.indexWhere((l) => l.id == levelId);
      if (lvlIdx != -1) {
        final targetLvl = c.levels[lvlIdx];
        final updatedLessons = targetLvl.lessons.where((l) => l.id != lessonId).toList();
        for (int i = 0; i < updatedLessons.length; i++) {
          updatedLessons[i] = updatedLessons[i].copyWith(order: i + 1);
        }
        final updatedLvl = targetLvl.copyWith(lessons: updatedLessons);
        final updatedLvls = List<CourseLevel>.from(c.levels);
        updatedLvls[lvlIdx] = updatedLvl;
        _currentCourses = List<Course>.from(_currentCourses);
        _currentCourses[courseIdx] = c.copyWith(levels: updatedLvls);
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
      }
    }

    try {
      await _coursesRepository.deleteLessonFromLevel(
        courseId,
        levelId,
        lessonId,
      );
      if (!isClosed) {
        emit(AdminCoursesActionSuccess('تم حذف الدرس بنجاح.', List<Course>.from(_currentCourses)));
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        // عند حدوث مهلة، لا نتراجع عن الحذف في واجهة المستخدم لأن فايربيز يقوم بتنفيذها محلياً ومزامنتها
        if (!isClosed) {
          emit(AdminCoursesActionSuccess('تم حذف الدرس بنجاح وجاري مزامنته مع الخادم.', List<Course>.from(_currentCourses)));
        }
        return;
      }
      _currentCourses = rollback;
      if (!isClosed) {
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        emit(AdminCoursesError('فشل حذف الدرس: $e', _currentCourses));
      }
    }
  }

  /// تحديث حالة نشر المحاضرة (نشر فوري، جدولة في موعد محدد، أو مسودة)
  Future<bool> updateLessonPublishStatus({
    required String courseId,
    required String levelId,
    required String lessonId,
    required bool isPublished,
    DateTime? scheduledPublishAt,
  }) async {
    final rollback = List<Course>.from(_currentCourses);
    final courseIdx = _currentCourses.indexWhere((c) => c.id == courseId);
    if (courseIdx != -1) {
      final c = _currentCourses[courseIdx];
      final lvlIdx = c.levels.indexWhere((l) => l.id == levelId);
      if (lvlIdx != -1) {
        final targetLvl = c.levels[lvlIdx];
        final lesIdx = targetLvl.lessons.indexWhere((l) => l.id == lessonId);
        if (lesIdx != -1) {
          final updatedLes = targetLvl.lessons[lesIdx].copyWith(
            isPublished: isPublished,
            scheduledPublishAt: scheduledPublishAt,
          );
          final updatedLessons = List<Lesson>.from(targetLvl.lessons);
          updatedLessons[lesIdx] = updatedLes;
          final updatedLvl = targetLvl.copyWith(lessons: updatedLessons);
          final updatedLvls = List<CourseLevel>.from(c.levels);
          updatedLvls[lvlIdx] = updatedLvl;
          _currentCourses = List<Course>.from(_currentCourses);
          _currentCourses[courseIdx] = c.copyWith(levels: updatedLvls);
          emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        }
      }
    }

    try {
      await _coursesRepository.updateLessonPublishStatus(
        courseId,
        levelId,
        lessonId,
        isPublished: isPublished,
        scheduledPublishAt: scheduledPublishAt,
      );
      if (!isClosed) {
        emit(
          AdminCoursesActionSuccess(
            isPublished
                ? (scheduledPublishAt != null
                    ? 'تمت جدولة موعد نشر المحاضرة بنجاح!'
                    : 'تم نشر المحاضرة للطلاب الآن!')
                : 'تم تحويل المحاضرة إلى مسودة.',
            List<Course>.from(_currentCourses),
          ),
        );
      }
      return true;
    } catch (e) {
      _currentCourses = rollback;
      if (!isClosed) {
        emit(AdminCoursesLoaded(List<Course>.from(_currentCourses)));
        emit(AdminCoursesError('فشل تعديل حالة نشر المحاضرة: $e', _currentCourses));
      }
      return false;
    }
  }

  /// تغيير طريقة إتاحة الكورس للطلاب.
  Future<bool> setAccessMode(String courseId, CourseAccessMode mode) async {
    try {
      await _coursesRepository.setCourseAccessMode(courseId, mode);
      if (!isClosed) {
        emit(AdminCoursesActionSuccess('تم تحديث حالة إتاحة الكورس.', _currentCourses));
      }
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(AdminCoursesError('فشل تحديث حالة الكورس: $e', _currentCourses));
      }
      return false;
    }
  }

  /// تعيين (أو إلغاء تعيين) طلاب محددين لكورس دفعة واحدة.
  Future<bool> assignStudents({
    required String courseId,
    required List<String> studentIds,
    required bool grant,
  }) async {
    try {
      final changed = await _coursesRepository.assignStudents(
        courseId: courseId,
        studentIds: studentIds,
        grant: grant,
      );
      if (!isClosed) {
        emit(
          AdminCoursesActionSuccess(
            grant
                ? 'تم تعيين $changed طالب للكورس.'
                : 'تم إلغاء تعيين $changed طالب من الكورس.',
            _currentCourses,
          ),
        );
      }
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(AdminCoursesError('فشلت عملية التعيين: $e', _currentCourses));
      }
      return false;
    }
  }

  /// فحص ومزامنة حالة معالجة فيديو درس معين من سيرفرات Mux مع حماية صارمة من التكرار والكوتا
  Future<void> syncLessonVideoStatus(
    String courseId,
    String levelId,
    Lesson lesson,
  ) async {
    final assetId = lesson.muxAssetId;
    if (assetId == null || assetId.trim().isEmpty) return;
    try {
      final statusInfo = await _muxRepository.getAssetStatus(assetId);
      if (statusInfo.isReady) {
        if (lesson.videoStatus == 'ready' &&
            lesson.duration.isNotEmpty &&
            lesson.duration != 'تلقائية (Mux)') {
          return;
        }
        await _coursesRepository.updateLessonVideoStatus(
          courseId,
          levelId,
          lesson.id,
          videoStatus: 'ready',
          videoProgress: 100.0,
          duration: statusInfo.formatDuration(),
        );
      } else if (statusInfo.isErrored) {
        if (lesson.videoStatus == 'error') return;
        await _coursesRepository.updateLessonVideoStatus(
          courseId,
          levelId,
          lesson.id,
          videoStatus: 'error',
          videoErrorMessage:
              statusInfo.errorMessage ?? 'تعذر سحب الفيديو من الرابط',
        );
      } else {
        final progressDiff = (statusInfo.progress - lesson.videoProgress).abs();
        if (lesson.videoStatus == 'processing' && progressDiff < 15.0) {
          return;
        }
        await _coursesRepository.updateLessonVideoStatus(
          courseId,
          levelId,
          lesson.id,
          videoStatus: 'processing',
          videoProgress: statusInfo.progress,
        );
      }
    } catch (_) {}
  }

  /// فحص ومزامنة تلقائية لكافة الدروس التي ما زالت قيد المعالجة السحابية
  Future<void> syncAllProcessingLessons() async {
    if (_isSyncingLessons) return;
    _isSyncingLessons = true;
    try {
      for (final course in _currentCourses) {
        for (final level in course.levels) {
          for (final lesson in level.lessons) {
            if (lesson.isVideoProcessing && lesson.muxAssetId != null) {
              await syncLessonVideoStatus(course.id, level.id, lesson);
            }
          }
        }
      }
    } finally {
      _isSyncingLessons = false;
    }
  }

  @override
  Future<void> close() {
    _processingSyncTimer?.cancel();
    _coursesSubscription?.cancel();
    return super.close();
  }
}
