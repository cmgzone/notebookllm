// Stub file for permission_handler package on web platform
// This provides empty implementations to allow compilation on web

class Permission {
  static final microphone = Permission._();
  static final camera = Permission._();

  Permission._();

  Future<PermissionStatus> request() async {
    return PermissionStatus.granted;
  }

  Future<PermissionStatus> get status async {
    return PermissionStatus.granted;
  }
}

enum PermissionStatus {
  denied,
  granted,
  restricted,
  limited,
  permanentlyDenied,
}

extension PermissionStatusExtension on PermissionStatus {
  bool get isDenied => this == PermissionStatus.denied;
  bool get isGranted => this == PermissionStatus.granted;
  bool get isRestricted => this == PermissionStatus.restricted;
  bool get isLimited => this == PermissionStatus.limited;
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
}
