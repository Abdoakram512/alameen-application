import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/utils/video_link_normalizer.dart';
import '../../../logic/courses/admin_courses_cubit.dart';
import '../../../models/lesson.dart';
import '../../../repositories/mux_repository.dart';
import 'lesson_assignment_form.dart';
import 'lesson_basic_form_fields.dart';
import 'lesson_publishing_schedule_box.dart';
import 'lesson_video_settings_box.dart';
import 'mux_video_upload_box.dart';

class AddLessonBottomSheet extends StatefulWidget {
  final String courseId;
  final String levelId;

  const AddLessonBottomSheet({
    super.key,
    required this.courseId,
    required this.levelId,
  });

  static Future<void> show(
    BuildContext context, {
    required String courseId,
    required String levelId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 580),
      builder: (_) => BlocProvider.value(
        value: context.read<AdminCoursesCubit>(),
        child: AddLessonBottomSheet(courseId: courseId, levelId: levelId),
      ),
    );
  }

  @override
  State<AddLessonBottomSheet> createState() => _AddLessonBottomSheetState();
}

class _AddLessonBottomSheetState extends State<AddLessonBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _muxRepository = sl<MuxRepository>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController();
  final _playbackIdController = TextEditingController();
  final _linkController = TextEditingController();
  final _assignmentForm = LessonAssignmentFormController();
  String _itemType = 'video'; // 'video' | 'assignment'
  VideoSourceMode _sourceMode = VideoSourceMode.link;
  String? _muxAssetId;
  String _videoStatus = 'ready';
  String? _videoSourceUrl;
  bool _isFreePreview = false;
  int _completionThreshold = 95;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadDetails = '';
  String _uploadSpeed = '';
  String _uploadStatus = '';
  bool _isSaving = false;
  String _publishOption = 'immediate'; // 'immediate' | 'schedule' | 'draft'
  DateTime? _scheduledDateTime;
  bool _isPickerActive = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _playbackIdController.dispose();
    _linkController.dispose();
    _assignmentForm.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadVideo() async {
    if (_isPickerActive || _isUploading) return;
    _isPickerActive = true;
    try {
      final files = await FilePicker.pickFiles(type: FileType.video);
      if (!mounted) return;
      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final totalBytes = await file.length();
        final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
        final stopwatch = Stopwatch()..start();

        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
          _uploadDetails = '0.0 MB / $totalMB MB';
          _uploadSpeed = '';
          _uploadStatus = 'جاري بدء رفع الفيديو إلى سيرفرات Mux...';
        });

        try {
          final uploadRes = await _muxRepository.processFullUpload(
            file,
            onProgress: (sentBytes, total) {
              if (!mounted) return;
              final progress = (sentBytes / total).clamp(0.0, 1.0);
              final sentMB = (sentBytes / (1024 * 1024)).toStringAsFixed(1);
              final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
              final speed = elapsedSec > 0.5
                  ? ((sentBytes / (1024 * 1024)) / elapsedSec).toStringAsFixed(1)
                  : '0.0';
              setState(() {
                _uploadProgress = progress;
                _uploadDetails = '$sentMB MB / $totalMB MB';
                _uploadSpeed = '$speed MB/s';
              });
            },
            onStatusUpdate: (status) {
              if (!mounted) return;
              setState(() {
                _uploadStatus = status;
              });
            },
          );
          if (mounted) {
            setState(() {
              _isUploading = false;
              _playbackIdController.text = uploadRes.playbackId;
              _muxAssetId = uploadRes.assetId;
              _videoStatus = 'ready';
              _uploadStatus = 'تم تجهيز الفيديو وتوليد رابط البث بنجاح.';
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isUploading = false;
              _uploadStatus =
                  'خطأ في الرفع: ${e.toString().replaceFirst('Exception: ', '')}';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = 'تعذر اختيار ملف الفيديو: $e';
        });
      }
    } finally {
      _isPickerActive = false;
    }
  }

  /// تسجيل الرابط فورياً في Mux (خلال 1-2 ثانية) دون حجز الأدمن لملفات الـ 10GB
  Future<void> _importFromLink() async {
    final rawLink = _linkController.text.trim();
    if (rawLink.isEmpty) {
      setState(() => _uploadStatus = 'خطأ: يرجى إدخال رابط الفيديو أولاً.');
      return;
    }
    final normalized = VideoLinkNormalizer.normalize(rawLink);
    if (normalized == null) {
      setState(
        () => _uploadStatus =
            'خطأ: الرابط غير صالح. استخدم رابط https لملف فيديو (Drive/Dropbox/مباشر).',
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'جاري تسجيل الفيديو في سيرفرات Mux السحابية...';
    });

    try {
      final res = await _muxRepository.registerUrlAsset(normalized.url);
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _playbackIdController.text = res.playbackId;
        _muxAssetId = res.assetId;
        _videoStatus = 'processing';
        _videoSourceUrl = normalized.url;
        _uploadStatus =
            'تم تسجيل الفيديو بنجاح! يسحب Mux الملف سحابياً في الخلفية. يمكنك حفظ الدرس الآن.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadStatus =
            'خطأ في تسجيل الفيديو: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime ?? now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      confirmText: 'التالي',
      cancelText: 'إلغاء',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledDateTime != null
          ? TimeOfDay.fromDateTime(_scheduledDateTime!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار موعد في المستقبل لنشر المحاضرة تلقائياً'),
        ),
      );
      return;
    }

    setState(() {
      _scheduledDateTime = combined;
    });
  }

  Future<void> _onSaveLesson() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<AdminCoursesCubit>();
    final title = _titleController.text.trim();
    var playbackId = _playbackIdController.text.trim();
    final isAssignmentItem = _itemType == 'assignment';

    if (_publishOption == 'schedule' && _scheduledDateTime == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد تاريخ ووقت موعد المحاضرة المجدولة'),
        ),
      );
      return;
    }

    final isPublished = _publishOption != 'draft';
    final scheduledPublishAt =
        _publishOption == 'schedule' ? _scheduledDateTime : null;

    if (isAssignmentItem) {
      _assignmentForm.enabled = true;
      if (_assignmentForm.titleController.text.trim().isEmpty) {
        _assignmentForm.titleController.text = title;
      }
      if (_assignmentForm.instructionsController.text.trim().isEmpty &&
          _descController.text.trim().isNotEmpty) {
        _assignmentForm.instructionsController.text =
            _descController.text.trim();
      }
      _assignmentForm.blocksNextLesson = true;
    } else {
      // إذا وضع الأدمن رابطاً ولم يضغط زر السحب، نسجله تلقائياً في ثانيتين
      if (playbackId.isEmpty &&
          _sourceMode == VideoSourceMode.link &&
          _linkController.text.trim().isNotEmpty) {
        final rawLink = _linkController.text.trim();
        final normalized = VideoLinkNormalizer.normalize(rawLink);
        if (normalized == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'الرابط غير صالح. يرجى إدخال رابط فيديو صالح من Drive أو Dropbox',
              ),
            ),
          );
          return;
        }
        setState(() {
          _isSaving = true;
          _uploadStatus = 'جاري تسجيل الفيديو في السحابة وحفظ الدرس فوراً...';
        });
        try {
          final res = await _muxRepository.registerUrlAsset(normalized.url);
          playbackId = res.playbackId;
          _muxAssetId = res.assetId;
          _videoStatus = 'processing';
          _videoSourceUrl = normalized.url;
        } catch (e) {
          if (!mounted) return;
          setState(() => _isSaving = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'فشل سحب الفيديو: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
            ),
          );
          return;
        }
      }

      if (playbackId.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'يرجى إدخال رابط الفيديو أو رفع ملف أو إدخال Playback ID',
            ),
          ),
        );
        return;
      }
    }

    final assignmentError = _assignmentForm.validate();
    if (assignmentError != null) {
      messenger.showSnackBar(SnackBar(content: Text(assignmentError)));
      return;
    }

    final newLesson = Lesson(
      id: 'les_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descController.text.trim(),
      duration: isAssignmentItem
          ? 'مهمة تطبيقية'
          : (_durationController.text.trim().isNotEmpty
              ? AppValidators.formatDurationArabic(
                  _durationController.text.trim(),
                )
              : 'تلقائية (Mux)'),
      muxPlaybackId: isAssignmentItem ? '' : playbackId,
      muxAssetId: isAssignmentItem ? null : _muxAssetId,
      isFreePreview: isAssignmentItem ? false : _isFreePreview,
      type: isAssignmentItem ? 'assignment' : 'video',
      lockNextUntilSubmitted:
          isAssignmentItem ? true : _assignmentForm.blocksNextLesson,
      videoStatus: isAssignmentItem ? 'ready' : _videoStatus,
      videoProgress:
          (isAssignmentItem || _videoStatus != 'processing') ? 100.0 : 0.0,
      videoSourceUrl: isAssignmentItem ? null : _videoSourceUrl,
      completionThresholdPercentage:
          isAssignmentItem ? 100 : _completionThreshold,
      isPublished: isPublished,
      scheduledPublishAt: scheduledPublishAt,
    );

    setState(() => _isSaving = true);
    if (!mounted) return;
    // إغلاق النافذة فوراً لمنح تجربة مستخدم سريعة وفورية، ومنع الضغط المتكرر الذي يسبب تكرار الدروس
    Navigator.pop(context);

    // إطلاق حفظ الدرس في الخلفية بواسطة الكيوبت مع التحديث المتفائل
    unawaited(
      cubit.addLesson(
        widget.courseId,
        widget.levelId,
        newLesson,
        assignment: _assignmentForm.build(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _itemType == 'assignment'
                    ? 'إضافة مهمة تطبيقية / تكليف جديد'
                    : 'إضافة درس فيديو جديد',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              LessonBasicFormFields(
                formKey: _formKey,
                itemType: _itemType,
                onItemTypeChanged: (type) {
                  setState(() {
                    _itemType = type;
                    if (_itemType == 'assignment') {
                      _assignmentForm.enabled = true;
                      _assignmentForm.blocksNextLesson = true;
                    }
                  });
                },
                titleController: _titleController,
                descController: _descController,
                durationController: _durationController,
              ),
              if (_itemType == 'video') ...[
                const SizedBox(height: 12),
                LessonVideoSettingsBox(
                  isFreePreview: _isFreePreview,
                  onFreePreviewChanged: (val) =>
                      setState(() => _isFreePreview = val),
                  completionThreshold: _completionThreshold,
                  onCompletionThresholdChanged: (val) =>
                      setState(() => _completionThreshold = val),
                ),
                const SizedBox(height: 12),
                MuxVideoUploadBox(
                  isUploading: _isUploading,
                  isSaving: _isSaving,
                  uploadStatus: _uploadStatus,
                  uploadProgress: _uploadProgress,
                  uploadDetails: _uploadDetails,
                  uploadSpeed: _uploadSpeed,
                  playbackIdController: _playbackIdController,
                  linkController: _linkController,
                  mode: _sourceMode,
                  onModeChanged: (m) => setState(() => _sourceMode = m),
                  onPickVideo: _pickAndUploadVideo,
                  onImportLink: _importFromLink,
                ),
                const SizedBox(height: 14),
                LessonAssignmentForm(
                  controller: _assignmentForm,
                  enabled: !_isSaving && !_isUploading,
                  isStandalone: false,
                ),
              ] else ...[
                const SizedBox(height: 14),
                LessonAssignmentForm(
                  controller: _assignmentForm,
                  enabled: !_isSaving && !_isUploading,
                  isStandalone: true,
                ),
              ],
              const SizedBox(height: 16),
              LessonPublishingScheduleBox(
                publishOption: _publishOption,
                onPublishOptionChanged: (opt) {
                  setState(() {
                    _publishOption = opt;
                    if (_publishOption == 'schedule' &&
                        _scheduledDateTime == null) {
                      _scheduledDateTime =
                          DateTime.now().add(const Duration(hours: 2));
                    }
                  });
                },
                scheduledDateTime: _scheduledDateTime,
                onPickScheduleDateTime: _pickScheduleDateTime,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isUploading || _isSaving ? null : _onSaveLesson,
                  child: Text(
                    _isSaving
                        ? 'جاري الحفظ...'
                        : (_itemType == 'assignment'
                            ? 'حفظ وإضافة المهمة إلى المستوى'
                            : 'حفظ وإضافة الدرس إلى المستوى'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
