import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_validators.dart';
import '../../services/mux_service.dart';

class MuxSettingsDialog extends StatefulWidget {
  const MuxSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const MuxSettingsDialog(),
    );
  }

  @override
  State<MuxSettingsDialog> createState() => _MuxSettingsDialogState();
}

class _MuxSettingsDialogState extends State<MuxSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tokenIdController = TextEditingController();
  final _tokenSecretController = TextEditingController();
  final _muxService = MuxService();

  bool _isLoading = false;
  String? _statusMessage;
  bool? _isSuccess;

  @override
  void initState() {
    super.initState();
    _tokenIdController.text = _muxService.tokenId;
    _tokenSecretController.text = _muxService.tokenSecret;
  }

  @override
  void dispose() {
    _tokenIdController.dispose();
    _tokenSecretController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final id = _tokenIdController.text.trim();
    final secret = _tokenSecretController.text.trim();

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final previousId = _muxService.tokenId;
    final previousSecret = _muxService.tokenSecret;
    _muxService.tokenId = id;
    _muxService.tokenSecret = secret;
    final success = await _muxService.verifyCredentials();
    if (!success) {
      _muxService.tokenId = previousId;
      _muxService.tokenSecret = previousSecret;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = success;
        _statusMessage = success
            ? 'mux.connection_success'.tr()
            : 'mux.connection_failed'.tr();
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final id = _tokenIdController.text.trim();
    final secret = _tokenSecretController.text.trim();

    await _muxService.saveCredentials(id, secret);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('mux.saved_success'.tr()),
        backgroundColor: AppColors.successDark,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.royalNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.video_settings_rounded,
                      color: AppColors.royalNavy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'mux.settings_title'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'dialogs.cancel'.tr(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 16),

              // Fields
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تُستخدم هذه المفاتيح أثناء جلسة المشرف الحالية لرفع الفيديوهات مباشرة، وتُمسح تلقائياً عند تسجيل الخروج.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tokenIdController,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            labelText: '${'mux.token_id'.tr()} *',
                            hintText: 'mux.token_id_hint'.tr(),
                            prefixIcon: const Icon(Icons.key_outlined, color: AppColors.royalNavy),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => AppValidators.validateRequired(
                            v,
                            'mux.token_id'.tr(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _tokenSecretController,
                          obscureText: true,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            labelText: '${'mux.token_secret'.tr()} *',
                            hintText: 'mux.token_secret_hint'.tr(),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.royalNavy),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => AppValidators.validateRequired(
                            v,
                            'mux.token_secret'.tr(),
                          ),
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _isSuccess == true
                                  ? AppColors.successLight
                                  : AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isSuccess == true
                                    ? AppColors.successBorder
                                    : AppColors.errorBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isSuccess == true ? Icons.check_circle : Icons.error,
                                  color: _isSuccess == true
                                      ? AppColors.success
                                      : AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isSuccess == true
                                          ? AppColors.successDark
                                          : AppColors.errorDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : _testConnection,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('mux.test_connection'.tr()),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.royalNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'dialogs.save'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
