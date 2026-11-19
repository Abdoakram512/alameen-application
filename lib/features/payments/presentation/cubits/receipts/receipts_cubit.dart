import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../../../repositories/student_payment_repository.dart';
import '../../../domain/entities/receipt_history.dart';
import 'receipts_state.dart';

/// Cubit مسؤول حصراً عن جلب وعرض سجل الإيصالات المالية للطالب.
/// لا يمنح أو يتحقق من أهلية الدورات، ولا يرسل إيصالات، ولا يطلق إشعارات.
class ReceiptsCubit extends Cubit<ReceiptsState> {
  final StudentPaymentRepository _repository;
  int _loadGeneration = 0;
  String? _activeStudentId;

  ReceiptsCubit({
    required StudentPaymentRepository repository,
  })  : _repository = repository,
        super(const ReceiptsInitial());

  String? get activeStudentId => _activeStudentId;

  Future<void> loadReceipts({
    required String studentId,
    bool silent = false,
  }) async {
    final normalizedId = studentId.trim();
    if (normalizedId.isEmpty) {
      clear();
      return;
    }

    final isSameStudent = _activeStudentId == normalizedId;
    _activeStudentId = normalizedId;
    final generation = ++_loadGeneration;
    final previousHistory = isSameStudent ? state.historyOrNull : null;

    if (!silent && !isClosed) {
      emit(ReceiptsLoading(previousHistory: previousHistory));
    }

    try {
      final receipts = await _repository.getStudentReceipts();
      if (isClosed ||
          generation != _loadGeneration ||
          _activeStudentId != normalizedId) {
        return;
      }

      if (receipts.isEmpty) {
        emit(const ReceiptsEmpty());
      } else {
        emit(ReceiptsLoaded(history: ReceiptHistory(receipts: receipts)));
      }
    } on AppFailure catch (failure) {
      if (isClosed ||
          generation != _loadGeneration ||
          _activeStudentId != normalizedId) {
        return;
      }
      emit(
        ReceiptsFailure(
          failure: failure,
          previousHistory: previousHistory,
        ),
      );
    } catch (_) {
      if (isClosed ||
          generation != _loadGeneration ||
          _activeStudentId != normalizedId) {
        return;
      }
      emit(
        ReceiptsFailure(
          failure: const UnknownFailure(
            'تعذر تحديث سجل الإيصالات المالية حالياً.',
          ),
          previousHistory: previousHistory,
        ),
      );
    }
  }

  Future<void> refresh({bool silent = true}) async {
    final uid = _activeStudentId;
    if (uid == null || uid.isEmpty) return;
    await loadReceipts(studentId: uid, silent: silent);
  }

  void clear() {
    _loadGeneration++;
    _activeStudentId = null;
    if (!isClosed) {
      emit(const ReceiptsInitial());
    }
  }

  @override
  Future<void> close() {
    _loadGeneration++;
    _activeStudentId = null;
    return super.close();
  }
}
