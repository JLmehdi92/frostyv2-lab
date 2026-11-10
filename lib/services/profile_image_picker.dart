import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onset/models/profile_edit.dart';

Future<ProfileImagePick?> pickProfileImage() async {
  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
  } catch (e) {
    debugPrint('Picking a profile image failed: ${e.runtimeType}');
    return const ProfileImagePick(null);
  }
  if (picked == null) return null;
  final length = await picked.length();
  if (length > ProfileImageFile.maxBytes) return const ProfileImagePick(null);
  return ProfileImagePick(
    ProfileImageFile.fromNamed(picked.name, await picked.readAsBytes()),
  );
}
