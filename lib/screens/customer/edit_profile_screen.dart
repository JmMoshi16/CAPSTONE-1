import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/profile_rules.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ui.dart';
import 'account_sheets.dart';

/// Edit profile: photo, username, and a way to change the password. Returns true when something was saved.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user, this.pickImage, this.save});

  final UserModel user;

  /// Test seams. Defaults: image_picker, and FirebaseService.updateProfile.
  final Future<Uint8List?> Function(ImageSource source)? pickImage;
  final Future<void> Function(String uid, {required String username, Uint8List? photo, bool removePhoto})? save;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.user.username);
  late Uint8List? _photo = widget.user.photo;
  Uint8List? _newPhoto;     // picked in this session
  bool _removePhoto = false;
  bool _saving = false;

  bool get _nameChanged => _name.text.trim() != widget.user.username;
  bool get _dirty => _nameChanged || _newPhoto != null || _removePhoto;
  bool get _canSave => _dirty && usernameError(_name.text) == null && !_saving;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  static Future<Uint8List?> _defaultPick(ImageSource source) async {
    // 256 px at quality 70 is about 20-40 KB: small enough to keep on the user document, sharp at avatar sizes.
    final file = await ImagePicker().pickImage(
      source: source, maxWidth: 256, maxHeight: 256, imageQuality: 70, preferredCameraDevice: CameraDevice.front);
    return file?.readAsBytes();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final bytes = await (widget.pickImage ?? _defaultPick)(source);
      if (bytes == null || !mounted) return;   // the user cancelled
      final problem = photoError(bytes.length);
      if (problem != null) {
        AppSnackbar.error(context, problem);
        return;
      }
      setState(() { _photo = bytes; _newPhoto = bytes; _removePhoto = false; });
    } on PlatformException {
      if (!mounted) return;
      final where = source == ImageSource.camera ? 'camera' : 'photos';
      AppSnackbar.show(context, 'ECOReward needs access to your $where. You can allow it in Settings.',
          kind: SnackKind.error, actionLabel: 'Settings', onAction: () => AppSettings.openAppSettings());
    }
  }

  void _photoOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery); },
          ),
          if (_photo != null)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: ctx.colors.danger),
              title: Text('Remove photo', style: TextStyle(color: ctx.colors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() { _photo = null; _newPhoto = null; _removePhoto = widget.user.photo != null; });
              },
            ),
          const SizedBox(height: AppSpace.xs),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final name = _name.text.trim();
    setState(() => _saving = true);
    try {
      await (widget.save ?? FirebaseService.updateProfile)(
          widget.user.uid, username: name, photo: _newPhoto, removePhoto: _removePhoto);
      // Only after the write succeeded.
      widget.user.username = name;
      if (_newPhoto != null) widget.user.photo = _newPhoto;
      if (_removePhoto) widget.user.photo = null;
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackbar.error(context, 'Could not save your profile. Check your connection and try again.');
      }
    }
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your changes to your profile have not been saved.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text('Discard', style: TextStyle(color: ctx.colors.danger))),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context, false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.xs),
              child: _saving
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpace.md),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  : TextButton(onPressed: _canSave ? _save : null, child: const Text('Save')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xl),
          children: [
            Center(
              child: Tap(
                label: 'Change profile photo',
                onTap: _photoOptions,
                child: Stack(clipBehavior: Clip.none, children: [
                  UserAvatar(name: _name.text, photo: _photo, size: 104),
                  Positioned(
                    right: -2, bottom: -2,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle,
                          border: Border.all(color: c.background, width: 3)),
                      child: Icon(Icons.photo_camera_rounded, size: 18, color: c.onPrimary),
                    ),
                  ),
                ]),
              ),
            ),
            Center(child: TextButton(onPressed: _photoOptions,
                child: Text(_photo == null ? 'Add photo' : 'Change photo'))),
            const SizedBox(height: AppSpace.md),
            Text('Username', style: t.labelLarge),
            const SizedBox(height: AppSpace.xs),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.done,
              maxLength: 20,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) => usernameError(v ?? ''),
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                hintText: 'Your name on the leaderboard',
                helperText: 'Shown on the leaderboard. Letters, numbers, spaces, dots and underscores.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text('Email', style: t.labelLarge),
            const SizedBox(height: AppSpace.xs),
            TextFormField(
              initialValue: widget.user.email,
              enabled: false,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded),
                  helperText: 'Your sign-in email cannot be changed here.'),
            ),
            const SizedBox(height: AppSpace.lg),
            SettingsGroup(children: [
              SettingsRow(
                icon: Icons.password_rounded,
                title: 'Change password',
                subtitle: 'We email you a reset link',
                onTap: () => confirmPasswordReset(context, widget.user.email),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
