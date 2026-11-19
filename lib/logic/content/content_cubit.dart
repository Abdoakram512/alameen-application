import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/student_content_repository.dart';
import 'content_state.dart';

class ContentCubit extends Cubit<ContentState> {
  final StudentContentRepository _repository;

  ContentCubit({required StudentContentRepository repository})
      : _repository = repository,
        super(const ContentInitial());

  Future<void> loadAboutUs() async {
    emit(const ContentLoading());
    try {
      final data = await _repository.getAboutUs();
      emit(ContentAboutLoaded(
        title: data['title'] ?? 'مركز الأمين للتخاطب والتأهيل',
        content: data['content'] ?? '',
      ));
    } catch (e) {
      emit(ContentError('تعذر تحميل بيانات من نحن: $e'));
    }
  }

  Future<void> loadFaqs() async {
    emit(const ContentLoading());
    try {
      final faqs = await _repository.getFaqs();
      emit(ContentFaqsLoaded(faqs: faqs));
    } catch (e) {
      emit(ContentError('تعذر تحميل الأسئلة الشائعة: $e'));
    }
  }

  Future<void> loadPrivacyPolicy() async {
    emit(const ContentLoading());
    try {
      final data = await _repository.getPrivacyPolicy();
      emit(ContentPrivacyLoaded(
        title: data['title'] ?? 'سياسة الخصوصية وسرية المعلومات',
        content: data['content'] ?? '',
      ));
    } catch (e) {
      emit(ContentError('تعذر تحميل سياسة الخصوصية: $e'));
    }
  }

  Future<void> loadContactInfo() async {
    emit(const ContentLoading());
    try {
      final info = await _repository.getContactInfo();
      if (info != null) {
        emit(ContentContactLoaded(contactInfo: info));
      } else {
        emit(const ContentError('بيانات التواصل غير متاحة حالياً.'));
      }
    } catch (e) {
      emit(ContentError('تعذر تحميل بيانات التواصل: $e'));
    }
  }
}
