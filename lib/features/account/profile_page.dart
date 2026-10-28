import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services.dart';
import '../../shared/widgets.dart';
import 'account_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.services, this.userId});
  final AppServices services;
  final String? userId;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;
  String get id => widget.userId ?? widget.services.session.user!.id;

  Future<void> perform(
    Future<void> Function() action,
    VoidCallback reload,
  ) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        reload();
        showMessage(context, 'Profile updated.');
      }
    } catch (error) {
      if (mounted) showMessage(context, safeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> edit(UserProfile profile, VoidCallback reload) async {
    final first = TextEditingController(text: profile.firstName);
    final last = TextEditingController(text: profile.lastName);
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: first,
                validator: nameText,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              TextFormField(
                controller: last,
                validator: nameText,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final firstName = first.text, lastName = last.text;
    // Dialog controllers live until its exit animation finishes.
    Future<void>.delayed(const Duration(seconds: 1), () {
      first.dispose();
      last.dispose();
    });
    if (accepted == true && mounted) {
      await perform(() async {
        await widget.services.account.update(id, firstName, lastName);
      }, reload);
    }
  }

  Future<void> pick(ImageSource source, VoidCallback reload) =>
      perform(() async {
        final image = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        if (image != null) await widget.services.account.upload(id, image);
      }, reload);

  @override
  Widget build(BuildContext context) => ContentPage(
    title: widget.userId == null ? 'My profile' : 'User profile',
    actions: widget.userId == null
        ? [
            IconButton(
              tooltip: 'Account settings',
              onPressed: () => context.push('/account'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ]
        : null,
    children: [
      RemoteContent<UserProfile>(
        load: () => widget.services.account.profile(id),
        builder: (profile, reload) {
          final image = widget.services.config.imageUri(profile.imageUrl);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipOval(
                  child: image == null
                      ? const Icon(Icons.account_circle, size: 120)
                      : Image.network(
                          image.toString(),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.account_circle, size: 120),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                profile.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(profile.email),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : () => edit(profile, reload),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => pick(ImageSource.gallery, reload),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => pick(ImageSource.camera, reload),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take a photo'),
              ),
              if (image != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await confirmAction(
                            context,
                            'Remove profile image?',
                            'Your current profile image will be deleted.',
                          )) {
                            await perform(
                              () => widget.services.account.removeImage(id),
                              reload,
                            );
                          }
                        },
                  child: const Text('Remove image'),
                ),
              if (_busy) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    ],
  );
}
