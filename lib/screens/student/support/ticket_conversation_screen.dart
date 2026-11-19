import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../logic/support/ticket_conversation_cubit.dart';
import '../../../logic/support/ticket_conversation_state.dart';
import '../../../models/support_ticket.dart';
import '../../../repositories/student_support_repository.dart';

class TicketConversationScreen extends StatefulWidget {
  final int ticketId;
  final TicketConversationCubit? cubit;
  final StudentSupportRepository? repository;

  const TicketConversationScreen({
    super.key,
    required this.ticketId,
    this.cubit,
    this.repository,
  });

  @override
  State<TicketConversationScreen> createState() => _TicketConversationScreenState();
}

class _TicketConversationScreenState extends State<TicketConversationScreen>
    with WidgetsBindingObserver {
  late final TicketConversationCubit _cubit;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _replyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _ownsCubit = false;

  final List<String> _replyAttachmentPaths = [];
  Timer? _pollingTimer;
  bool _isPollingActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else if (widget.repository != null) {
      _cubit = TicketConversationCubit(
        repository: widget.repository!,
        ticketId: widget.ticketId,
      );
      _ownsCubit = true;
    } else {
      _cubit = sl<TicketConversationCubit>(param1: widget.ticketId);
      _ownsCubit = true;
    }

    _cubit.loadTicket().then((_) {
      _scrollToBottom();
      _startPolling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _scrollController.dispose();
    _replyController.dispose();
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_isPollingActive) return;
    _isPollingActive = true;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      final hasNew = await _cubit.pollUpdates();
      if (hasNew) {
        _scrollToBottom();
      }
    });
  }

  void _stopPolling() {
    _isPollingActive = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAttachment() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          _replyAttachmentPaths.add(file.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر اختيار الملف: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _replyAttachmentPaths.removeAt(index);
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty && _replyAttachmentPaths.isEmpty) return;

    try {
      await _cubit.sendReply(
        message: text.isNotEmpty ? text : 'مرفق ملف توضيحي',
        attachmentPaths: _replyAttachmentPaths.isNotEmpty ? List.from(_replyAttachmentPaths) : null,
      );
      _replyController.clear();
      setState(() {
        _replyAttachmentPaths.clear();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الرد: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleTicketStatus(SupportTicket ticket) async {
    final shouldClose = ticket.isOpen;
    try {
      if (shouldClose) {
        await _cubit.closeTicket();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إغلاق التذكرة بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await _cubit.reopenTicket();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إعادة فتح التذكرة'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة التذكرة: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<TicketConversationCubit, TicketConversationState>(
        builder: (context, state) {
          SupportTicket? ticket;
          if (state is TicketConversationLoaded) {
            ticket = state.ticket;
          }

          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket != null ? ticket.ticketNumber : 'تذكرة الدعم',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  if (ticket != null)
                    Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (ticket != null)
                  TextButton.icon(
                    onPressed: () => _toggleTicketStatus(ticket!),
                    icon: Icon(
                      ticket.isOpen ? PhosphorIconsRegular.xCircle : PhosphorIconsRegular.arrowClockwise,
                      size: 18,
                      color: ticket.isOpen ? AppColors.textMuted : AppColors.primary,
                    ),
                    label: Text(
                      ticket.isOpen ? 'إغلاق' : 'إعادة فتح',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ticket.isOpen ? AppColors.textMuted : AppColors.primary,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: _buildBody(state),
            bottomNavigationBar: ticket != null ? _buildReplyBar(ticket, state) : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(TicketConversationState state) {
    if (state is TicketConversationLoading || state is TicketConversationInitial) {
      return const AppLoadingIndicator(message: 'جاري تحميل المحادثة...');
    }

    if (state is TicketConversationError) {
      return AppErrorView(
        message: state.message,
        onRetry: () => _cubit.loadTicket(),
      );
    }

    if (state is TicketConversationLoaded) {
      final ticket = state.ticket;
      final messages = state.messages;

      return Column(
        children: [
          // Ticket summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.borderHairline),
              ),
            ),
            child: Row(
              children: [
                _buildStatusBadge(ticket.status, ticket.statusLabel),
                const SizedBox(width: 8),
                if (ticket.categoryLabel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.categoryLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (ticket.priorityLabel.isNotEmpty)
                  _buildPriorityBadge(ticket.priority, ticket.priorityLabel),
              ],
            ),
          ),

          // Message stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessageBubble(SupportMessage message) {
    if (message.isSystemEvent) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final isStudent = message.isFromStudent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isStudent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isStudent) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsRegular.headset,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isStudent ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isStudent ? 16 : 4),
                  bottomRight: Radius.circular(isStudent ? 4 : 16),
                ),
                border: isStudent
                    ? null
                    : Border.all(color: AppColors.borderHairline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isStudent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isStudent && message.senderName.isNotEmpty) ...[
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isStudent ? Colors.white : AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  if (message.attachmentUrl != null &&
                      message.attachmentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isStudent
                            ? Colors.white.withValues(alpha: 0.15)
                            : AppColors.primaryLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            message.isImage
                                ? PhosphorIconsRegular.image
                                : PhosphorIconsRegular.file,
                            size: 16,
                            color: isStudent ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              message.attachmentName ?? 'مرفق',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isStudent ? Colors.white : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    message.timeAgo ?? '',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isStudent
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar(SupportTicket ticket, TicketConversationState state) {
    final isClosed = ticket.isClosed;
    final isSending = state is TicketConversationLoaded && state.isSendingReply;

    if (isClosed) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsRegular.lock, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              const Text(
                'هذه التذكرة مغلقة حالياً.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _toggleTicketStatus(ticket),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 0,
                ),
                child: const Text('إعادة الفتح', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyAttachmentPaths.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(_replyAttachmentPaths.length, (index) {
                  final path = _replyAttachmentPaths[index];
                  final name = path.split(Platform.pathSeparator).last;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsRegular.fileImage, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeAttachment(index),
                          child: const Icon(PhosphorIconsRegular.x, size: 12, color: AppColors.error),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: _pickAttachment,
                  icon: const Icon(PhosphorIconsRegular.paperclip, color: AppColors.textSecondary),
                  tooltip: 'إرفاق صورة',
                ),
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'اكتب ردك هنا...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isSending ? null : _sendReply,
                  icon: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(PhosphorIconsFill.paperPlaneTilt, color: AppColors.primary),
                  tooltip: 'إرسال الرد',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, String label) {
    AppStatusType type = AppStatusType.neutral;
    final s = status.toLowerCase();
    if (s == 'open') {
      type = AppStatusType.info;
    } else if (s == 'in_progress') {
      type = AppStatusType.warning;
    } else if (s == 'resolved' || s == 'closed') {
      type = AppStatusType.success;
    }

    return AppStatusBadge(
      label: label.isNotEmpty ? label : status,
      statusType: type,
    );
  }

  Widget _buildPriorityBadge(String priority, String label) {
    Color fg = AppColors.textSecondary;
    final p = priority.toLowerCase();
    if (p == 'urgent' || p == 'high') {
      fg = AppColors.error;
    } else if (p == 'normal') {
      fg = AppColors.primary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsRegular.flag, size: 13, color: fg),
        const SizedBox(width: 3),
        Text(
          label.isNotEmpty ? label : priority,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
