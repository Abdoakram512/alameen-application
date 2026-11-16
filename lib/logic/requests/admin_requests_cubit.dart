import '../../core/utils/network_error_mapper.dart';
import '../../models/access_request.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/requests_repository.dart';
import '../../repositories/impl/requests_repository_impl.dart';
import '../../services/notification_service.dart';
import 'admin_requests_state.dart';

class AdminRequestsCubit extends Cubit<AdminRequestsState> {
  final RequestsRepository _requestsRepository;
  StreamSubscription? _requestsSubscription;
  List<CourseAccessRequest> _cached = [];
  final _busyIds = <String>{};
  final _seenPendingIds = <String>{};
  bool _initialSnapshotHandled = false;

  AdminRequestsCubit({RequestsRepository? requestsRepository})
    : _requestsRepository = requestsRepository ?? RequestsRepositoryImpl(),
      super(AdminRequestsLoading());

  void loadRequests() {
    emit(AdminRequestsLoading());
    _requestsSubscription?.cancel();
    _initialSnapshotHandled = false;
    _requestsSubscription = _requestsRepository.streamRequests().listen(
      (requests) {
        final currentPending = requests
            .where((r) => r.status == AccessStatus.pending)
            .toList();

        if (!_initialSnapshotHandled) {
          _initialSnapshotHandled = true;
          _seenPendingIds
            ..clear()
            ..addAll(currentPending.map((r) => r.id));
        } else {
          for (final req in currentPending) {
            if (_seenPendingIds.add(req.id)) {
              unawaited(
                AdminNotificationService().showInstantNotification(
                  id: req.id.hashCode,
                  title: 'طلب اشتراك جديد',
                  body:
                      'أرسل ${req.studentName} إيصال سداد لدورة "${req.courseTitle}".',
                  payload: '/dashboard',
                ),
              );
            }
          }
        }

        _cached = List.unmodifiable(requests);
        emit(AdminRequestsLoaded(_cached));
      },
      onError: (e) {
        emit(
          AdminRequestsError(
            NetworkErrorMapper.toArabicMessage(
              e,
              defaultMessage: 'تعذر تحميل طلبات الاشتراك.',
            ),
            requests: _cached,
          ),
        );
      },
    );
  }

  bool isRequestBusy(String id) => _busyIds.contains(id);

  Future<void> approveRequest({
    required String requestId,
    required String studentId,
    required String courseId,
    required String studentName,
    String? levelId,
  }) async {
    if (!_busyIds.add(requestId)) return;

    // Optimistic local update for instantaneous UI feedback
    final updatedList = _cached.map((req) {
      if (req.id == requestId) {
        return req.copyWith(
          status: AccessStatus.approved,
          reviewedAt: DateTime.now(),
        );
      }
      return req;
    }).toList();
    _cached = updatedList;
    emit(AdminRequestsLoaded(updatedList));

    try {
      await _requestsRepository.approveRequest(
        requestId,
        studentId,
        courseId,
        levelId: levelId,
      );
      emit(
        AdminRequestsActionSuccess(
          'requests.success_approved'.tr(),
          requests: _cached,
        ),
      );
    } catch (e) {
      emit(
        AdminRequestsError(
          'تعذر اعتماد الطلب. حدّث القائمة وتحقق من حالته قبل إعادة المحاولة.',
          requests: _cached,
        ),
      );
    } finally {
      _busyIds.remove(requestId);
    }
  }

  Future<void> rejectRequest(String requestId, {String adminNotes = ''}) async {
    if (!_busyIds.add(requestId)) return;

    // Optimistic local update for instantaneous UI feedback
    final updatedList = _cached.map((req) {
      if (req.id == requestId) {
        return req.copyWith(
          status: AccessStatus.rejected,
          adminNotes: adminNotes,
          reviewedAt: DateTime.now(),
        );
      }
      return req;
    }).toList();
    _cached = updatedList;
    emit(AdminRequestsLoaded(updatedList));

    try {
      await _requestsRepository.rejectRequest(
        requestId,
        adminNotes: adminNotes,
      );
      emit(
        AdminRequestsActionSuccess(
          'requests.success_rejected'.tr(),
          requests: _cached,
        ),
      );
    } catch (e) {
      emit(
        AdminRequestsError(
          'تعذر رفض الطلب. حدّث القائمة ثم حاول مرة أخرى.',
          requests: _cached,
        ),
      );
    } finally {
      _busyIds.remove(requestId);
    }
  }

  @override
  Future<void> close() {
    _requestsSubscription?.cancel();
    return super.close();
  }
}
