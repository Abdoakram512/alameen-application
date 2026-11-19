import 'package:equatable/equatable.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../domain/entities/receipt_history.dart';

sealed class ReceiptsState extends Equatable {
  const ReceiptsState();

  /// سجل الإيصالات المتاح حالياً (للعرض المالي فقط وليس للأهلية).
  ReceiptHistory? get historyOrNull => switch (this) {
        ReceiptsLoaded(history: final h) => h,
        ReceiptsLoading(previousHistory: final h) => h,
        ReceiptsFailure(previousHistory: final h) => h,
        _ => null,
      };

  @override
  List<Object?> get props => [];
}

final class ReceiptsInitial extends ReceiptsState {
  const ReceiptsInitial();
}

final class ReceiptsLoading extends ReceiptsState {
  final ReceiptHistory? previousHistory;

  const ReceiptsLoading({this.previousHistory});

  @override
  List<Object?> get props => [previousHistory];
}

final class ReceiptsLoaded extends ReceiptsState {
  final ReceiptHistory history;

  const ReceiptsLoaded({required this.history});

  @override
  List<Object?> get props => [history];
}

final class ReceiptsEmpty extends ReceiptsState {
  const ReceiptsEmpty();
}

final class ReceiptsFailure extends ReceiptsState {
  final AppFailure failure;
  final ReceiptHistory? previousHistory;

  const ReceiptsFailure({
    required this.failure,
    this.previousHistory,
  });

  @override
  List<Object?> get props => [failure, previousHistory];
}
