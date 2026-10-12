import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/supported_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../data/onboarding_controller.dart';

/// First-run language selection. Completing it unlocks the rest of the app.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    final Locale device = WidgetsBinding.instance.platformDispatcher.locale;
    final bool supported =
        kSupportedLanguages.any((AppLanguage l) => l.code == device.languageCode);
    _selectedCode = supported ? device.languageCode : 'en';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.onboardingTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.onboardingSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RadioGroup<String>(
                groupValue: _selectedCode,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _selectedCode = value);
                  }
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: kSupportedLanguages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final AppLanguage language = kSupportedLanguages[index];
                    return RadioListTile<String>(
                      value: language.code,
                      title: Text(language.nativeName),
                      subtitle: language.nativeName == language.englishName
                          ? null
                          : Text(language.englishName),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: _onContinue,
                child: Text(l10n.continueLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onContinue() async {
    await ref
        .read(localeControllerProvider.notifier)
        .setLocale(Locale(_selectedCode));
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }
}
