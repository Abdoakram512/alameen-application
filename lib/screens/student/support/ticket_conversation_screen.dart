import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/support_ticket.dart';
import '../../../repositories/student_support_repository.dart';

class TicketConversationScreen extends StatefulWidget {
  final int ticketId;
  final StudentSupportRepository? repository;

  const TicketConversationScreen({
    super.key,
    required this.ticketId,
    this.repository,
  });

  @override
  State<TicketConversationScreen> createState() => _TicketConversationScreenState();
}

class _TicketConversationScreenState extends State<TicketConversationScreen>
    with WidgetsBindingObserver {
  late final StudentSupportRepository _repository;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _replyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  SupportTicket? _ticket;
  List<SupportMessage> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool _isSendingReply = false;
  final List<String> _replyAttachmentPaths = [];

  Timer? _pollingTimer;
  bool _isPollingActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository ?? sl<StudentSupportRepository>();
    _loadTicketDetails();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _scrollController.dispose();
    _replyController.dispose();
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _pollUpdates();
    });
  }

  void _stopPolling() {
    _isPollingActive = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  int get _lastMessageId {
    if (_messages.isEmpty) return 0;
    return _messages.map((m) => m.id).reduce((a, b) => a > b ? a : b);
  }

  Future<void> _loadTicketDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = await _repository.getTicketDetails(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _messages = List<SupportMessage>.from(ticket.messages);
        _isLoading = false;
      });
      _scrollToBottom();
      _startPolling();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل بيانات التذكرة: $e';
      });
    }
  }

  Future<void> _pollUpdates() async {
    if (!mounted || _isLoading || _ticket == null) return;

    try {
      final pollResult = await _repository.pollTicketUpdates(
        ticketId: widget.ticketId,
        afterId: _lastMessageId,
      );

      if (!mounted) return;

      bool shouldScroll = false;
      setState(() {
        if (pollResult.isClosed && _ticket!.isOpen) {
          _ticket = _ticket!.copyWith(
            status: pollResult.ticketStatus ?? 'closed',
            statusLabel: pollResult.ticketStatusLabel ?? 'مغلقة',
            isClosed: true,
            isOpen: false,
          );
        } else if (pollResult.ticketStatus != null &&
            pollResult.ticketStatus != _ticket!.status) {
          _ticket = _ticket!.copyWith(
            status: pollResult.ticketStatus!,
            statusLabel: pollResult.ticketStatusLabel ?? _ticket!.statusLabel,
          );
        }

        if (pollResult.messages.isNotEmpty) {
          final existingIds = _messages.map((m) => m.id).toSet();
          for (final msg in pollResult.messages) {
            if (!existingIds.contains(msg.id)) {
              _messages.add(msg);
              shouldScroll = true;
            }
          }
        }
      });

      if (shouldScroll) {
        _scrollToBottom();
      }
    } catch (_) {
      // Ignore polling errors silently to avoid disturbing the user
    }
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

    setState(() => _isSendingReply = true);

    try {
      final message = await _repository.replyToTicket(
        ticketId: widget.ticketId,
        message: text.isNotEmpty ? text : 'مرفق ملف توضيحي',
        attachmentPaths: _replyAttachmentPaths.isNotEmpty ? _replyAttachmentPaths : null,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _replyController.clear();
        _replyAttachmentPaths.clear();
        _isSendingReply = false;
        // If ticket was closed, replying might reopen or mark as awaiting response
        if (_ticket != null && _ticket!.isClosed) {
          _ticket = _ticket!.copyWith(
            isOpen: true,
            isClosed: false,
            status: 'open',
            statusLabel: 'مفتوحة',
          );
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingReply = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الرد: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleTicketStatus() async {
    if (_ticket == null) return;

    final shouldClose = _ticket!.isOpen;
    try {
      if (shouldClose) {
        await _repository.closeTicket(_ticket!.id);
        setState(() {
          _ticket = _ticket!.copyWith(
            isOpen: false,
            isClosed: true,
            status: 'closed',
            statusLabel: 'مغلقة',
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إغلاق التذكرة بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await _repository.reopenTicket(_ticket!.id);
        setState(() {
          _ticket = _ticket!.copyWith(
            isOpen: true,
            isClosed: false,
            status: 'open',
            statusLabel: 'مفتوحة',
          );
        });
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
    final ticket = _ticket;

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
              onPressed: _toggleTicketStatus,
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
      body: _buildBody(),
      bottomNavigationBar: _buildReplyBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTicketDetails,
                icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ticket = _ticket!;

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
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _buildMessageBubble(message);
            },
          ),
        ),
      ],
    );
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

  Widget _buildReplyBar() {
    final ticket = _ticket;
    final isClosed = ticket != null && ticket.isClosed;

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
                onPressed: _toggleTicketStatus,
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
                  onPressed: _isSendingReply ? null : _sendReply,
                  icon: _isSendingReply
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
    Color bg = const Color(0xFFE5E7EB);
    Color fg = const Color(0xFF374151);

    final s = status.toLowerCase();
    if (s == 'open') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else if (s == 'in_progress') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (s == 'resolved' || s == 'closed') {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.isNotEmpty ? label : status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
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
