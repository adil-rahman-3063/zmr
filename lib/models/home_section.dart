enum SectionType {
  carousel,
  shelf,
  unknown
}

class HomeSection {
  final String title;
  final List<dynamic> items; // Can be Song, ZmrPlaylist, or Artist
  final SectionType type;

  HomeSection({
    required this.title,
    required this.items,
    this.type = SectionType.shelf,
  });
}
