import 'dart:collection';

class ConnectionStatusModel {
  bool isConnected;
  ConnectionStatusModel({
    required this.isConnected,
  });

  factory ConnectionStatusModel.fromJson(HashMap<dynamic, dynamic> parsedJson) {
    return ConnectionStatusModel(
      isConnected: parsedJson['isConnected'],
    );
  }
}
