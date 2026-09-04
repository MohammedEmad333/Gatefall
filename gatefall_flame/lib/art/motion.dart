import '../runtime_stub.dart' if (dart.library.io) '../runtime_io.dart';

/// Version 3 put animation everywhere, and animation has one consequence
/// worth writing down: a widget test's `pumpAndSettle` waits for the frame
/// queue to go quiet, and an ambient loop never lets it. Rather than
/// scattering `if (kDebugMode)` or making every test opt out, the ambient
/// layer asks here, once.
///
/// [Motion.ambient] is off under `flutter test` and on everywhere else, so
/// the game breathes on a device and holds still for a test. Everything
/// that reads it must still render a sensible *frame* when it is off — a
/// disabled animation is a still image, never a blank one.
class Motion {
  Motion._();

  /// Never-ending animations: drifting motes, the turning rift, breathing
  /// portraits, the pulse on a ready ability.
  static bool ambient = !runningUnderTest;

  /// One-shot animations with an end: a hit flash, a floating number, a
  /// screen entering. These are safe under `pumpAndSettle` because they
  /// finish, so they stay on in tests — which is also the only way a test
  /// can assert that a transition ends where it should.
  static bool transitions = true;

  /// Scales a one-shot duration. Kept as a function so a "reduce motion"
  /// setting has exactly one place to land later.
  static Duration quick(Duration d) => transitions ? d : Duration.zero;
}
