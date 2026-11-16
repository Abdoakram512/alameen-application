import 'package:flutter/material.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dialogs/receipt_preview_dialog.dart';
import '../../../core/widgets/feedback/app_error_state.dart';
import '../../../models/access_request.dart';
import '../../../models/registered_student.dart';
import '../../../repositories/requests_repository.dart';

class StudentReceiptsTabView extends StatefulWidget {
  final RegisteredStudent student;

  const StudentReceiptsTabView({super.key, required this.student});

  @override
  State<StudentReceiptsTabView> createState() => _StudentReceiptsTabViewState();
}

class _StudentReceiptsTabViewState extends State<StudentReceiptsTabView> {
  late Stream<List<CourseAccessRequest>> _requestsStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant StudentReceiptsTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id) {
      _initStream();
    }
  }

  void _initStream() {
    _requestsStream = sl<RequestsRepository>().streamStudentRequests(
      widget.student.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CourseAccessRequest>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AppErrorState(
            message: 'تعذر تحميل الإيصالات. تحقق من الاتصال وحاول مرة أخرى.',
            onRetry: () => setState(_initStream),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 54,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد طلبات أو إيصالات دفع مسجلة لهذا المتدرب',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            ResponsiveCenter(
              maxWidth: 920,
              child: ResponsiveCardGrid(
                minItemWidth: 380,
                maxColumns: 2,
                mainAxisSpacing: 12,
                children: requests.map((req) {
                  final isApproved = req.status == AccessStatus.approved;
                  final isPending = req.status == AccessStatus.pending;

                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isPending
                            ? AppColors.warningBorder
                            : (isApproved
                                  ? AppColors.successBorder
                                  : AppColors.cardBorder),
                      ),
                    ),
                    color: isPending ? AppColors.warningLight : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  req.courseTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? AppColors.successLight
                                      : (isPending
                                            ? AppColors.warningLight
                                            : AppColors.errorLight),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isApproved
                                        ? AppColors.successBorder
                                        : (isPending
                                              ? AppColors.warningBorder
                                              : AppColors.errorBorder),
                                  ),
                                ),
                                child: Text(
                                  isApproved
                                      ? 'تمت الموافقة'
                                      : (isPending ? 'قيد المراجعة' : 'مرفوض'),
                                  style: TextStyle(
                                    color: isApproved
                                        ? AppColors.successDark
                                        : (isPending
                                              ? AppColors.warningDark
                                              : AppColors.errorDark),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'طريقة الدفع: ${req.paymentMethod} • رقم التحويل: ${req.senderNumberOrRef.isNotEmpty ? req.senderNumberOrRef : "غير محدد"}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'تاريخ الطلب: ${req.requestedAt.year}/${req.requestedAt.month}/${req.requestedAt.day}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          if (req.receiptUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => ReceiptPreviewDialog.show(
                                context,
                                imageUrl: req.receiptUrl,
                              ),
                              icon: const Icon(Icons.image_outlined, size: 16),
                              label: const Text('معاينة صورة الإيصال'),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              'مُرسل برقم التحويل دون إرفاق صورة',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
