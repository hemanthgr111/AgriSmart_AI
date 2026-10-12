import 'dart:convert';
import 'dart:typed_data';

import 'package:agrismart_app/core/media/image_picker_provider.dart';
import 'package:agrismart_app/core/network/api_client.dart';
import 'package:agrismart_app/features/diagnosis/data/diagnosis_models.dart';
import 'package:agrismart_app/features/diagnosis/data/diagnosis_repository.dart';
import 'package:agrismart_app/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:agrismart_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakeRepository extends DiagnosisRepository {
  _FakeRepository() : super(ApiClient());

  @override
  Future<DiagnosisResult> diagnose({
    required List<int> bytes,
    required String filename,
  }) async {
    return const DiagnosisResult(
      crop: 'Tomato',
      disease: 'Late blight',
      isHealthy: false,
      confidence: 0.82,
      advice: 'Remove infected plants.',
      predictions: <DiagnosisPrediction>[
        DiagnosisPrediction(
          label: 'Tomato___Late_blight',
          crop: 'Tomato',
          disease: 'Late blight',
          isHealthy: false,
          confidence: 0.82,
          advice: 'Remove infected plants.',
        ),
        DiagnosisPrediction(
          label: 'Potato___Late_blight',
          crop: 'Potato',
          disease: 'Late blight',
          isHealthy: false,
          confidence: 0.10,
          advice: 'Act quickly.',
        ),
      ],
    );
  }
}

void main() {
  // A valid 1x1 PNG so Image.memory can decode a real preview.
  final Uint8List pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  testWidgets('Diagnosis screen uploads a photo and shows the result',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pickImageProvider.overrideWithValue(
            (ImageSource source, {int? maxWidth, int? imageQuality}) async =>
                XFile.fromData(pngBytes, name: 'leaf.png'),
          ),
          diagnosisRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiagnosisScreen(),
        ),
      ),
    );

    expect(find.text('Add a leaf photo to begin.'), findsOneWidget);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();

    expect(find.text('Disease detected'), findsOneWidget);
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('Late blight'), findsWidgets);
    expect(find.text('82.0%'), findsOneWidget);
    expect(find.text('Remove infected plants.'), findsOneWidget);
  });
}
