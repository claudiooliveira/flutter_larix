class FocusModel {
  bool isAutoFocus;
  double distanceFocus;

  FocusModel({
    required this.isAutoFocus,
    required this.distanceFocus,
  });

  factory FocusModel.fromHashMap(value) => FocusModel(
        isAutoFocus: value["isAutoFocus"],
        distanceFocus: value["distanceFocus"],
      );
}
