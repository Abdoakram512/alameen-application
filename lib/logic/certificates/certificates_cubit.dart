import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/course_certificate.dart';
import '../../repositories/student_certificates_repository.dart';
import 'certificates_state.dart';

class CertificatesCubit extends Cubit<CertificatesState> {
  final StudentCertificatesRepository _repository;

  CertificatesCubit({
    required StudentCertificatesRepository repository,
  })  : _repository = repository,
        super(const CertificatesInitial());

  Future<void> loadCertificates({
    bool forceRefresh = false,
    String? currentStudentId,
  }) async {
    emit(const CertificatesLoading());

    try {
      final list = await _repository.getStudentCertificates(
        forceRefresh: forceRefresh,
        currentStudentId: currentStudentId,
      );

      emit(CertificatesLoaded(certificates: list));
    } on ApiException catch (e) {
      emit(CertificatesError(e.message));
    } catch (e) {
      emit(CertificatesError('تعذر تحميل الشهادات: $e'));
    }
  }

  Future<Uint8List> downloadCertificatePdf(String fileUrl) async {
    final currentState = state;
    if (currentState is CertificatesLoaded) {
      emit(currentState.copyWith(
        isDownloadingPdf: true,
        downloadingFileUrl: fileUrl,
      ));
    }

    try {
      final bytes = await _repository.downloadOfficialCertificatePdf(fileUrl);
      if (state is CertificatesLoaded) {
        emit((state as CertificatesLoaded).copyWith(
          isDownloadingPdf: false,
          downloadingFileUrl: null,
        ));
      }
      return bytes;
    } catch (e) {
      if (state is CertificatesLoaded) {
        emit((state as CertificatesLoaded).copyWith(
          isDownloadingPdf: false,
          downloadingFileUrl: null,
        ));
      }
      rethrow;
    }
  }

  Future<CertificateVerificationResult> verifyCertificate(String code) {
    return _repository.verifyCertificate(code);
  }
}
