/// Every route path in the app, in one place.
///
/// Paths are data, so they live here regardless of which router is wired up.
/// Feature code refers to these constants and calls `context.goTo(...)`, which
/// keeps screens from importing the router package directly.
abstract final class Routes {
  static const String clone = '/clone';
  static const String speak = '/speak';
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String llm = '/settings/llm';

  /// Where the app opens.
  static const String initial = clone;
}
