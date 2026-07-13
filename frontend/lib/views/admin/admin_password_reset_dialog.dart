import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/admin_provider.dart';

Future<void> showAdminPasswordResetDialog({
  required BuildContext context,
  required User user,
}) async {
  final pageContext = context;
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool isSaving = false;
  bool showPassword = false;
  bool showConfirmation = false;

  await showDialog<void>(
    context: pageContext,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            icon: const Icon(Icons.admin_panel_settings_rounded),
            title: Text(
              dialogContext
                  .tr('reset_password_for')
                  .replaceFirst('{name}', user.username),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogContext.tr('password_reset_explanation'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: dialogContext.tr('new_password'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                            () => showPassword = !showPassword,
                          ),
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 8
                          ? dialogContext.tr('password_min_8')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: !showConfirmation,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: dialogContext.tr('confirm_password'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(
                            () => showConfirmation = !showConfirmation,
                          ),
                          icon: Icon(
                            showConfirmation
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return dialogContext.tr('confirm_password_required');
                        }
                        if (value != passwordController.text) {
                          return dialogContext.tr('passwords_do_not_match');
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.tr('cancel')),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final admin = Provider.of<AdminProvider>(
                          pageContext,
                          listen: false,
                        );
                        final success = await admin.updateUserPassword(
                          user,
                          passwordController.text,
                        );

                        if (!pageContext.mounted || !dialogContext.mounted) {
                          return;
                        }
                        setDialogState(() => isSaving = false);

                        if (success) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                pageContext
                                    .tr('password_updated_for')
                                    .replaceFirst('{name}', user.username),
                              ),
                              backgroundColor: AppColors.secondary,
                            ),
                          );
                          return;
                        }

                        ScaffoldMessenger.of(pageContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              admin.error ??
                                  pageContext.tr('password_update_failed'),
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(dialogContext.tr('save')),
              ),
            ],
          );
        },
      );
    },
  );

  passwordController.dispose();
  confirmController.dispose();
}
