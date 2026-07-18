import '../entities/country.dart';

abstract interface class LineSpeaker {
  Future<void> speak({
    required String text,
    required Country country,
    required int speaker,
  });

  Future<void> stop();
}

class SilentLineSpeaker implements LineSpeaker {
  const SilentLineSpeaker();

  @override
  Future<void> speak({
    required String text,
    required Country country,
    required int speaker,
  }) async {}

  @override
  Future<void> stop() async {}
}
