import 'dart:collection';

class ConnectionStatisticsModel {
  int bandwidth;
  int traffic;

  ConnectionStatisticsModel({
    required this.bandwidth,
    required this.traffic,
  });

  factory ConnectionStatisticsModel.fromJson(
      HashMap<dynamic, dynamic> parsedJson) {
    return ConnectionStatisticsModel(
      bandwidth: parsedJson['bandwidth'],
      traffic: parsedJson['traffic'],
    );
  }
}
