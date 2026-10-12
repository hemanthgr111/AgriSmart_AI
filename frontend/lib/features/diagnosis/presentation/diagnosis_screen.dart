import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/image_picker_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../data/diagnosis_models.dart';
import '../data/diagnosis_repository.dart';

class DiagnosisScreen extends ConsumerStatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  ConsumerState<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends ConsumerState<DiagnosisScreen> {
  Uint8List? _bytes;
  String _filename = 'leaf.jpg';
  bool _loading = false;
  DiagnosisResult? _result;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final XFile? file = await ref.read(pickImageProvider)(source);
      if (file == null) {
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _bytes = bytes;
        _filename = file.name.isEmpty ? 'leaf.jpg' : file.name;
        _result = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.diagnosisFailed);
      }
    }
  }

  Future<void> _analyze() async {
    final Uint8List? bytes = _bytes;
    if (bytes == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final DiagnosisResult result = await ref
          .read(diagnosisRepositoryProvider)
          .diagnose(bytes: bytes, filename: _filename);
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).diagnosisFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _messageFor(ApiException error) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    switch (error.statusCode) {
      case 503:
        return l10n.diagnosisNotConfigured;
      case 400:
        return l10n.invalidImage;
      case 413:
        return l10n.imageTooLarge;
      default:
        return l10n.diagnosisFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diagnosisTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (_bytes == null)
            _EmptyPrompt(message: l10n.diagnoseNoImage)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _bytes!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.diagnoseTakePhoto),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.diagnoseChooseGallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_bytes == null || _loading) ? null : _analyze,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_loading ? l10n.analyzing : l10n.diagnoseAnalyze),
          ),
          const SizedBox(height: 20),
          if (_error != null) _ErrorCard(message: _error!),
          if (_result != null) _ResultCard(result: _result!),
        ],
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.eco_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = result.isHealthy ? scheme.primary : scheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  result.isHealthy ? Icons.check_circle : Icons.warning_amber,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.isHealthy ? l10n.resultHealthy : l10n.resultDiseased,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(label: l10n.resultCrop, value: result.crop),
            _DetailRow(label: l10n.resultDisease, value: result.disease),
            _DetailRow(
              label: l10n.resultConfidence,
              value: '${(result.confidence * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 16),
            Text(l10n.adviceTitle,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(result.advice, style: Theme.of(context).textTheme.bodyMedium),
            if (result.alternatives.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(l10n.otherPossibilities,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final DiagnosisPrediction alt in result.alternatives)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${alt.crop} — ${alt.disease}  '
                    '(${(alt.confidence * 100).toStringAsFixed(1)}%)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
