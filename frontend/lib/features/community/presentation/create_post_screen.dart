import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/image_picker_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/community_providers.dart';
import '../data/community_repository.dart';

/// Composer for a new community post (text and an optional photo).
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController _content = TextEditingController();
  Uint8List? _imageBytes;
  bool _submitting = false;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final XFile? file = await ref.read(pickImageProvider)(ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
    if (file == null) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (mounted) {
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_content.text.trim().isEmpty) {
      _showMessage(l10n.postContentRequired);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(communityRepositoryProvider).createPost(
            content: _content.text,
            imageBytes: _imageBytes,
          );
      ref.invalidate(feedProvider);
      if (mounted) {
        context.go(AppRoutes.community);
      }
    } on CommunityFailure catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(l10n.postFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createPost),
        actions: <Widget>[
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text(l10n.postPublish),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _content,
            minLines: 4,
            maxLines: 10,
            maxLength: 2000,
            enabled: !_submitting,
            decoration: InputDecoration(
              hintText: l10n.postHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_imageBytes != null)
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _imageBytes!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _imageBytes = null),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.postAddPhoto),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(l10n.postPublish),
          ),
        ],
      ),
    );
  }
}
