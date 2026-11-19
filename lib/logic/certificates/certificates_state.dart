import 'package:equatable/equatable.dart';
import '../../models/course_certificate.dart';

abstract class CertificatesState extends Equatable {
  const CertificatesState();

  @override
  List<Object?> get props => [];
}

class CertificatesInitial extends CertificatesState {
  const CertificatesInitial();
}

class CertificatesLoading extends CertificatesState {
  const CertificatesLoading();
}

class CertificatesLoaded extends CertificatesState {
  final List<CourseCertificate> certificates;
  final bool isDownloadingPdf;
  final String? downloadingFileUrl;

  const CertificatesLoaded({
    required this.certificates,
    this.isDownloadingPdf = false,
    this.downloadingFileUrl,
  });

  CertificatesLoaded copyWith({
    List<CourseCertificate>? certificates,
    bool? isDownloadingPdf,
    String? downloadingFileUrl,
  }) {
    return CertificatesLoaded(
      certificates: certificates ?? this.certificates,
      isDownloadingPdf: isDownloadingPdf ?? this.isDownloadingPdf,
      downloadingFileUrl: downloadingFileUrl ?? this.downloadingFileUrl,
    );
  }

  @override
  List<Object?> get props => [certificates, isDownloadingPdf, downloadingFileUrl];
}

class CertificatesError extends CertificatesState {
  final String message;

  const CertificatesError(this.message);

  @override
  List<Object?> get props => [message];
}
