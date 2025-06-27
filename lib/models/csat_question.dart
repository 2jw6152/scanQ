class CSATQuestion {
  final int? number;
  final String body;
  final List<String> choices;
  final List<String> imagePaths;

  CSATQuestion({this.number, required this.body, this.choices = const [], this.imagePaths = const []});
}
