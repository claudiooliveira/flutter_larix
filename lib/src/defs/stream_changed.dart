import 'dart:collection';

class StreamChanged {
  String connectionState;

  StreamChanged({
    required this.connectionState,
  });

  factory StreamChanged.fromJson(HashMap<dynamic, dynamic> parsedJson) {
    return StreamChanged(
      connectionState: parsedJson['connectionState'],
    );
  }
}
