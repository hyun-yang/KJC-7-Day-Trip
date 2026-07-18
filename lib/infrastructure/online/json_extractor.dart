/// Extracts the first complete top-level JSON object from [raw].
///
/// Braces inside quoted strings do not affect object depth. Escaped quote and
/// backslash characters are handled while scanning the string.
String extractJsonObject(String raw) {
  final start = raw.indexOf('{');
  if (start < 0) {
    throw const FormatException('No JSON object found');
  }

  var depth = 0;
  var inString = false;
  var escaped = false;

  for (var index = start; index < raw.length; index++) {
    final character = raw[index];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character == r'\') {
        escaped = true;
      } else if (character == '"') {
        inString = false;
      }
      continue;
    }

    if (character == '"') {
      inString = true;
    } else if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) {
        return raw.substring(start, index + 1);
      }
    }
  }

  throw const FormatException('Incomplete JSON object');
}
