import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Draws the launcher icon for every platform this app ships on.
///
/// Generated rather than committed as a binary, so there is one definition of
/// what the icon looks like and it can be re-rendered at any size a platform
/// asks for. Until now the app shipped Flutter's own logo, which says nothing
/// about what it is.
///
/// A waveform, not a microphone: the microphone belongs to Dictation, and two
/// apps from the same shelf should not wear the same mark.
void main() {
  _writeIco(
    File('windows/runner/resources/app_icon.ico'),
    const [16, 24, 32, 48, 64, 128, 256],
  );

  // Android's buckets, in the density order the folders are named for.
  const android = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in android.entries) {
    final file = File(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
    );
    file.writeAsBytesSync(_png(entry.value, _draw(entry.value)));
    stdout.writeln('  ${file.path}  ${entry.value}px');

    // The adaptive foreground is the waveform alone on transparency: Android
    // supplies the shape and shadow, and drawing our own plate underneath its
    // mask would show as a square inside a circle.
    //
    // Adaptive icons reserve the outer third for parallax and masking, so the
    // glyph is drawn into the middle 72dp of a 108dp canvas.
    final adaptive = (entry.value * 108) ~/ 48;
    final foreground = File(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png',
    );
    foreground.writeAsBytesSync(
      _png(adaptive, _draw(adaptive, plate: false, scale: 72 / 108)),
    );
  }
  _writeAdaptiveXml();
}

/// The Android 8+ icon: our waveform over a flat plate colour.
void _writeAdaptiveXml() {
  final dir = Directory('android/app/src/main/res/mipmap-anydpi-v26')
    ..createSync(recursive: true);

  const xml = '<?xml version="1.0" encoding="utf-8"?>\n'
      '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
      '    <background android:drawable="@color/ic_launcher_background" />\n'
      '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
      '</adaptive-icon>\n';
  for (final name in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
    File('${dir.path}/$name').writeAsStringSync(xml);
  }

  final hex = _plate.$1.toRadixString(16).padLeft(2, '0') +
      _plate.$2.toRadixString(16).padLeft(2, '0') +
      _plate.$3.toRadixString(16).padLeft(2, '0');
  File('android/app/src/main/res/values/ic_launcher_background.xml')
      .writeAsStringSync(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="ic_launcher_background">#$hex</color>\n'
    '</resources>\n',
  );
  stdout.writeln('  android/app/src/main/res/mipmap-anydpi-v26/  adaptive');
}

/// Indigo, which is the app's own default accent, and a near-white waveform.
const _plate = (0x4A, 0x57, 0xC8);
const _glyph = (0xF4, 0xF5, 0xFC);

/// Renders one square of RGBA pixels, top row first.
Uint8List _draw(int size, {bool plate = true, double scale = 1}) {
  final pixels = Uint8List(size * size * 4);

  // Three samples per axis. At 16 pixels this is the difference between a
  // waveform and a smudge.
  const samples = 3;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var plateCover = 0.0, glyph = 0.0;
      for (var sy = 0; sy < samples; sy++) {
        for (var sx = 0; sx < samples; sx++) {
          final u = (x + (sx + 0.5) / samples) / size;
          final v = (y + (sy + 0.5) / samples) / size;
          // `scale` shrinks the drawing about the centre, for the adaptive
          // foreground whose outer third is reserved for the system's mask.
          final su = (u - 0.5) / scale + 0.5;
          final sv = (v - 0.5) / scale + 0.5;
          if (plate && _inPlate(su, sv)) plateCover += 1;
          if (_inWaveform(su, sv)) glyph += 1;
        }
      }
      const total = samples * samples;
      plateCover /= total;
      glyph /= total;

      final alpha = math.max(plateCover, glyph);
      final mix = alpha == 0 ? 0.0 : glyph / alpha;

      final i = (y * size + x) * 4;
      pixels[i] = _blend(_plate.$1, _glyph.$1, mix);
      pixels[i + 1] = _blend(_plate.$2, _glyph.$2, mix);
      pixels[i + 2] = _blend(_plate.$3, _glyph.$3, mix);
      pixels[i + 3] = (alpha * 255).round();
    }
  }
  return pixels;
}

int _blend(int from, int to, double t) => (from + (to - from) * t).round();

/// A rounded square with a little breathing room.
bool _inPlate(double x, double y) {
  const inset = 0.045, radius = 0.20;
  const left = inset, right = 1 - inset;
  if (x < left || x > right || y < left || y > right) return false;
  final dx = math.max(math.max(left + radius - x, x - (right - radius)), 0.0);
  final dy = math.max(math.max(left + radius - y, y - (right - radius)), 0.0);
  return dx * dx + dy * dy <= radius * radius;
}

/// Five capsules of different heights — a voice, drawn the way a level meter
/// draws one.
///
/// Deliberately asymmetric. A symmetrical set reads as a chart; this reads as
/// speech.
bool _inWaveform(double x, double y) {
  const heights = [0.28, 0.56, 0.86, 0.62, 0.36];
  const barWidth = 0.10, gap = 0.05;
  const groupWidth = 5 * barWidth + 4 * gap;
  const firstLeft = (1 - groupWidth) / 2;
  const halfWidth = barWidth / 2;

  for (var i = 0; i < heights.length; i++) {
    final centre = firstLeft + i * (barWidth + gap) + halfWidth;
    final dx = (x - centre).abs();
    if (dx > halfWidth) continue;

    // Capsule: a straight middle with a rounded cap at each end.
    final half = heights[i] / 2;
    final top = 0.5 - half + halfWidth;
    final bottom = 0.5 + half - halfWidth;
    if (y >= top && y <= bottom) return true;
    final capY = y < top ? top : bottom;
    if (dx * dx + (y - capY) * (y - capY) <= halfWidth * halfWidth) return true;
  }
  return false;
}

/// A minimal PNG: one IHDR, one IDAT, one IEND.
///
/// Hand-rolled because the alternative is a package dependency for a build
/// script that writes five files.
Uint8List _png(int size, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    // Filter type 0 (none) for each scanline.
    raw
      ..addByte(0)
      ..add(Uint8List.sublistView(rgba, y * size * 4, (y + 1) * size * 4));
  }

  Uint8List chunk(String type, List<int> data) {
    final body = BytesBuilder()
      ..add(type.codeUnits)
      ..add(data);
    final bytes = body.toBytes();
    return (BytesBuilder()
          ..add(_u32be(data.length))
          ..add(bytes)
          ..add(_u32be(_crc32(bytes))))
        .toBytes();
  }

  return (BytesBuilder()
        ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(chunk('IHDR', [
          ..._u32be(size), ..._u32be(size),
          8, // bits per channel
          6, // colour type: RGBA
          0, 0, 0,
        ]))
        ..add(chunk('IDAT', ZLibCodec().encode(raw.toBytes())))
        ..add(chunk('IEND', [])))
      .toBytes();
}

/// Packs the images into an .ico of uncompressed 32-bit bitmaps.
void _writeIco(File out, List<int> sizes) {
  final images = [for (final s in sizes) _dib(s, _draw(s))];

  var offset = 6 + 16 * sizes.length;
  final header = BytesBuilder()
    ..add(_u16(0))
    ..add(_u16(1)) // 1 = icon
    ..add(_u16(sizes.length));

  for (var i = 0; i < sizes.length; i++) {
    header
      ..addByte(sizes[i] == 256 ? 0 : sizes[i]) // 0 means 256
      ..addByte(sizes[i] == 256 ? 0 : sizes[i])
      ..addByte(0) // true colour, so no palette
      ..addByte(0)
      ..add(_u16(1))
      ..add(_u16(32))
      ..add(_u32(images[i].length))
      ..add(_u32(offset));
    offset += images[i].length;
  }

  final file = BytesBuilder()..add(header.toBytes());
  for (final image in images) {
    file.add(image);
  }
  out.writeAsBytesSync(file.toBytes());
  stdout.writeln('  ${out.path}  (${sizes.join(", ")})');
}

/// One icon image: a BITMAPINFOHEADER, the pixels bottom-up as BGRA, then the
/// AND mask the format still requires even though the alpha channel does the
/// work.
Uint8List _dib(int size, Uint8List rgba) {
  final out = BytesBuilder()
    ..add(_u32(40))
    ..add(_u32(size))
    ..add(_u32(size * 2)) // colour rows and mask rows together
    ..add(_u16(1))
    ..add(_u16(32))
    ..add(_u32(0)) // BI_RGB
    ..add(_u32(size * size * 4))
    ..add(_u32(0))
    ..add(_u32(0))
    ..add(_u32(0))
    ..add(_u32(0));

  for (var y = size - 1; y >= 0; y--) {
    final row = Uint8List(size * 4);
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      row[x * 4] = rgba[i + 2]; // B
      row[x * 4 + 1] = rgba[i + 1]; // G
      row[x * 4 + 2] = rgba[i]; // R
      row[x * 4 + 3] = rgba[i + 3];
    }
    out.add(row);
  }

  out.add(Uint8List(((size + 31) ~/ 32) * 4 * size));
  return out.toBytes();
}

Uint8List _u16(int v) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);
Uint8List _u32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
Uint8List _u32be(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.big);

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
