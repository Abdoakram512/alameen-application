import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../repositories/student_content_repository.dart';
import 'content_state.dart';

class ContentCubit extends Cubit<ContentState> {
  final StudentContentRepository _repository;

  ContentCubit({StudentContentRepository? repository})
      : _repository = repository ?? sl<StudentContentRepository>(),
        super(const ContentInitial());

  Future<void> loadAboutUs() async {
    if (isClosed) return;
    emit(const ContentLoading());
    try {
      final data = await _repository.getAboutUs();
      if (isClosed) return;
      emit(ContentAboutLoaded(aboutUs: data));
    } catch (e) {
      if (isClosed) return;
      emit(ContentError('تعذر تحميل بيانات من نحن: $e'));
    }
  }

  Future<void> loadFaqs() async {
    if (isClosed) return;
    emit(const ContentLoading());
    try {
      final faqs = await _repository.getFaqs();
      if (isClosed) return;
      emit(ContentFaqsLoaded(faqs: faqs));
    } catch (e) {
      if (isClosed) return;
      emit(ContentError('تعذر تحميل الأسئلة الشائعة: $e'));
    }
  }

  Future<void> loadPrivacyPolicy() async {
    if (isClosed) return;
    emit(const ContentLoading());
    try {
      final data = await _repository.getPrivacyPolicy();
      if (isClosed) return;
      emit(ContentPrivacyLoaded(privacyPolicy: data));
    } catch (e) {
      if (isClosed) return;
      emit(ContentError('تعذر تحميل سياسة الخصوصية: $e'));
    }
  }

  Future<void> loadContactInfo() async {
    if (isClosed) return;
    emit(const ContentLoading());
    try {
      final info = await _repository.getContactInfo();
      if (isClosed) return;
      if (info != null) {
        emit(ContentContactLoaded(contactInfo: info));
      } else {
        emit(const ContentError('بيانات التواصل غير متاحة حالياً.'));
      }
    } catch (e) {
      if (isClosed) return;
      emit(ContentError('تعذر تحميل بيانات التواصل: $e'));
    }
  }
}
