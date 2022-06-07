import 'dart:collection';

class Permissions {
  bool hasAudioPermission;
  bool hasCameraPermission;

  Permissions({
    required this.hasAudioPermission,
    required this.hasCameraPermission,
  });

  factory Permissions.fromJson(HashMap<dynamic, dynamic> parsedJson) {
    return Permissions(
      hasAudioPermission: parsedJson['hasAudioPermission'],
      hasCameraPermission: parsedJson['hasCameraPermission'],
    );
  }
}
