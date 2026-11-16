import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../logic/requests/admin_requests_cubit.dart';
import '../../../models/access_request.dart';

class RejectRequestDialog extends StatefulWidget {
  final CourseAccessRequest request;

  const RejectRequestDialog({super.key, required this.request});

  static Future<void> show(BuildContext context, {required CourseAccessRequest request}) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<AdminRequestsCubit>(),
        child: RejectRequestDialog(request: request),
      ),
    );
  }

  @override
  State<RejectRequestDialog> createState() => _RejectRequestDialogState();
}

class _RejectRequestDialogState extends State<RejectRequestDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _onConfirmReject() {
    context.read<AdminRequestsCubit>().rejectRequest(
          widget.request.id,
          adminNotes: _reasonController.text.trim().isNotEmpty
              ? _reasonController.text.trim()
              : 'لم يتم استيفاء شروط الدفع',
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('requests.reject_dialog_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'requests.reject_confirm_msg'.tr(
              args: [widget.request.studentName, widget.request.courseTitle],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'requests.reject_reason_label'.tr(),
              hintText: 'requests.reject_reason_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('dialogs.cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _onConfirmReject,
          child: Text('requests.confirm_reject'.tr()),
        ),
      ],
    );
  }
}

