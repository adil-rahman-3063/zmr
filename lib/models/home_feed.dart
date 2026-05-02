import 'home_section.dart';
import 'home_chip.dart';

class HomeFeed {
  final List<HomeChip> chips;
  final List<HomeSection> sections;

  HomeFeed({
    required this.chips,
    required this.sections,
  });

  factory HomeFeed.empty() => HomeFeed(chips: [], sections: []);
}
