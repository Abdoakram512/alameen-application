import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/google_drive_file.dart';
import '../../../services/google_drive_service.dart';

/// شاشة / حوار استعراض واختيار ملفات الفيديو مباشرة من حساب Google Drive للأدمن.
class GoogleDrivePickerDialog extends StatefulWidget {
  const GoogleDrivePickerDialog({super.key});

  static Future<GoogleDriveFile?> show(BuildContext context) {
    return showModalBottomSheet<GoogleDriveFile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GoogleDrivePickerDialog(),
    );
  }

  @override
  State<GoogleDrivePickerDialog> createState() =>
      _GoogleDrivePickerDialogState();
}

class _GoogleDrivePickerDialogState extends State<GoogleDrivePickerDialog> {
  final _driveService = GoogleDriveService();
  final _searchController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  List<GoogleDriveFile> _files = [];

  @override
  void initState() {
    super.initState();
    _checkAndLoadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndLoadFiles() async {
    if (_driveService.isSignedIn) {
      await _fetchFiles();
    } else {
      // محاولة تسجيل الدخول الصامت أولاً
      setState(() => _isLoading = true);
      final silentAccount = await _driveService.signInSilently();
      if (!mounted) return;
      if (silentAccount != null) {
        await _fetchFiles();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final account = await _driveService.signIn();
    if (!mounted) return;

    if (account == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'تم إلغاء تسجيل الدخول أو تعذر الاتصال بـ Google';
      });
      return;
    }

    await _fetchFiles();
  }

  Future<void> _handleSignOut() async {
    await _driveService.signOut();
    if (!mounted) return;
    setState(() {
      _files = [];
      _errorMessage = null;
    });
  }

  Future<void> _fetchFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _driveService.fetchVideos(
        searchQuery: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _files = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _driveService.currentAccount;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 750),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
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
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_to_drive_rounded,
                          color: Color(0xFF1A73E8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Google Drive',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'اختر فيديو المحاضرة مباشرة من حسابك',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'فتح تطبيق Google Drive',
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 20,
                          color: Color(0xFF1A73E8),
                        ),
                        onPressed: _driveService.openGoogleDriveApp,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Account status bar
                  if (account != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLevel0,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderHairline),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: account.photoUrl != null
                                ? NetworkImage(account.photoUrl!)
                                : null,
                            child: account.photoUrl == null
                                ? const Icon(Icons.person, size: 16)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.displayName ?? 'حساب Google',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  account.email,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: _handleSignOut,
                            child: const Text(
                              'تبديل الحساب',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Search bar (only when signed in)
                  if (account != null) ...[
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'بحث في ملفات الفيديو في Drive...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchFiles();
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.borderHairline),
                        ),
                      ),
                      onSubmitted: (_) => _fetchFiles(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 8),

                  // Main content
                  Expanded(
                    child: _buildBody(account != null),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isSignedIn) {
    if (!isSignedIn) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  size: 40,
                  color: Color(0xFF1A73E8),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ربط حساب Google Drive',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'سجّل الدخول بحساب Google لتصفح ملفات الفيديو واختيارها مباشرة دون الحاجة لنسخ ولصق الروابط يدوياً.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : _handleSignIn,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded, size: 20),
                label: const Text(
                  'تسجيل الدخول بحساب Google',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _driveService.openGoogleDriveApp,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('فتح تطبيق Google Drive أولاً'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'جاري جلب ملفات الفيديو من Google Drive...',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _fetchFiles,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('إعادة المحاولة'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                    ),
                    onPressed: _driveService.openGoogleDriveApp,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('فتح تطبيق Drive'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('إلغاء والعودة للدرس'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library_outlined,
                  size: 44, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'لم يتم العثور على أي ملفات فيديو في Drive',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'تأكد من رفع فيديوهات المحاضرات على حسابك، أو افتح تطبيق Drive للرفع الآن.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                ),
                onPressed: _driveService.openGoogleDriveApp,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('فتح تطبيق Drive لرفع فيديو'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _files.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final file = _files[index];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Color(0xFF1A73E8),
              size: 26,
            ),
          ),
          title: Text(
            file.name,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          subtitle: Row(
            children: [
              Text(
                file.sizeFormatted,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (file.modifiedTime != null) ...[
                const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                Text(
                  '${file.modifiedTime!.year}/${file.modifiedTime!.month}/${file.modifiedTime!.day}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          trailing: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => Navigator.pop(context, file),
            child: const Text('اختيار', style: TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}
