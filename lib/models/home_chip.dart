class HomeChip {
  final String title;
  final String? browseId;
  final String? params;
  final bool isSelected;

  HomeChip({
    required this.title,
    this.browseId,
    this.params,
    this.isSelected = false,
  });

  factory HomeChip.fromMap(Map<String, dynamic> map) {
    final renderer = map['chipCloudChipRenderer'];
    if (renderer == null) throw Exception('Invalid chip renderer');

    return HomeChip(
      title: renderer['text']?['runs']?[0]?['text'] ?? 'Unknown',
      browseId: renderer['navigationEndpoint']?['browseEndpoint']?['browseId'],
      params: renderer['navigationEndpoint']?['browseEndpoint']?['params'],
      isSelected: renderer['isSelected'] ?? false,
    );
  }
}
