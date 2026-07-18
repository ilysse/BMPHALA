import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/localization/app_localizations.dart';

class LegalLinks extends StatelessWidget {
  static final Uri _privacyUrl = Uri.parse(
    'https://halawat.net/privacy-policy.html',
  );
  static final Uri _termsUrl = Uri.parse(
    'https://halawat.net/terms-of-service.html',
  );
  static final Uri _deletionUrl = Uri.parse(
    'https://halawat.net/account-deletion.html',
  );

  final Color color;
  final bool includeDeletion;

  const LegalLinks({
    super.key,
    this.color = AppColors.textLight,
    this.includeDeletion = true,
  });

  Future<void> _open(Uri url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final links = <({String label, Uri url})>[
      (label: context.tr('privacy_policy'), url: _privacyUrl),
      (label: context.tr('terms_of_service'), url: _termsUrl),
      if (includeDeletion)
        (label: context.tr('delete_account'), url: _deletionUrl),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 0,
      children: links
          .map(
            (link) => TextButton(
              onPressed: () => _open(link.url),
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                link.label,
                style: const TextStyle(
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                  decorationThickness: 0.7,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
