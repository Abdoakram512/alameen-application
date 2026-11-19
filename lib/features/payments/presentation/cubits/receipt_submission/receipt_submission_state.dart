import 'package:equatable/equatable.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../domain/entities/payment_receipt.dart';

sealed class ReceiptSubmissionState extends Equatable {
  const ReceiptSubmissionState();

  @override
  List<Object?> get props => [];
}

final class ReceiptSubmissionInitial extends ReceiptSubmissionState {
  const ReceiptSubmissionInitial();
}

final class ReceiptSubmissionInProgress extends ReceiptSubmissionState {
  const ReceiptSubmissionInProgress();
}

final class ReceiptSubmissionSuccess extends ReceiptSubmissionState {
  final PaymentReceipt receipt;
  final String message;

  const ReceiptSubmissionSuccess({
    required this.receipt,
    required this.message,
  });

  @override
  List<Object?> get props => [receipt, message];
}

final class ReceiptSubmissionValidationFailure extends ReceiptSubmissionState {
  final String message;
  final Map<String, List<String>> fieldErrors;

  const ReceiptSubmissionValidationFailure({
    required this.message,
    this.fieldErrors = const {},
  });

  @override
  List<Object?> get props => [message, fieldErrors];
}

final class ReceiptSubmissionNetworkFailure extends ReceiptSubmissionState {
  final String message;

  const ReceiptSubmissionNetworkFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

final class ReceiptSubmissionFailure extends ReceiptSubmissionState {
  final AppFailure failure;

  const ReceiptSubmissionFailure({required this.failure});

  @override
  List<Object?> get props => [failure];
}
