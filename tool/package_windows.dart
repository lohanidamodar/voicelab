import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;

/// Builds the Windows release: the Flutter bundle plus the native libraries
/// it loads, and a zip of the lot.
///
/// The libraries are fetched from their publishers rather than committed —
/// they are tens of megabytes of compiled code, and pinning them by release
/// tag here keeps the download honest about which build shipped.
///
/// No models. They are gigabytes, their licences are not ours to pass on, and
/// the app fetches the one the user chooses after showing the terms.
Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('out', defaultsTo: 'build/release')
    ..addOption(
      'audiocpp-dir',
      help: 'Directory holding a built audiocpp_c.dll. audio.cpp publishes '
          'only statically linked executables, so the shared library this '
          'app loads has to be built from source — the release workflow does '
          'that. Defaults to wherever the app would find one.',
    )
    ..addOption(
      'sherpa',
      defaultsTo: 'v1.13.4',
      help: 'sherpa-onnx release. Must match the sherpa_onnx package version, '
          'because the bindings resolve symbols by name.',
    )
    ..addFlag('skip-build', negatable: false, help: 'Package what is there.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(argv);
  if (args.flag('help')) {
    stdout.writeln('Usage: dart tool/package_windows.dart\n${parser.usage}');
    return;
  }
  if (!Platform.isWindows) {
    stderr.writeln('Windows only: `flutter build windows` builds for the '
        'platform it runs on.');
    exitCode = 1;
    return;
  }

  final version = _version();
  final out = Directory(args.option('out')!);
  final stage = Directory('${out.path}\\voicelab-$version-windows-x64');

  if (!args.flag('skip-build')) await _build();

  if (stage.existsSync()) stage.deleteSync(recursive: true);
  stage.createSync(recursive: true);

  stdout.writeln('\nvoicelab $version → ${stage.path}\n');
  _copyBundle(stage);

  _addAudioCpp(stage, args.option('audiocpp-dir'));
  await _addSherpa(stage, out, args.option('sherpa')!);
  _addDocuments(stage);
  await _addLicenceTexts(stage);

  final zip = File('${stage.path}.zip');
  _zip(stage, zip);
  stdout.writeln('\n${zip.path}  ${_size(zip.lengthSync())}');
}

String _version() {
  final line = File('pubspec.yaml')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('version:'), orElse: () => '');
  final version = line.split(':').last.trim();
  if (version.isEmpty) {
    throw StateError('No version in pubspec.yaml. Run this from the app root.');
  }
  // "1.2.3+45" — the build number is for the stores, not for a file name.
  return version.split('+').first;
}

Future<void> _build() async {
  stdout.writeln('building…');
  final result = await Process.run(
    'flutter',
    ['build', 'windows', '--release'],
    runInShell: true,
  );
  if (result.exitCode != 0) {
    stderr
      ..writeln(result.stdout)
      ..writeln(result.stderr);
    throw StateError('the build failed');
  }
}

/// Copies the whole Flutter bundle — the exe alone does not run.
void _copyBundle(Directory stage) {
  final bundle = Directory(r'build\windows\x64\runner\Release');
  if (!bundle.existsSync()) {
    throw StateError('No build at ${bundle.path}. Drop --skip-build.');
  }

  var files = 0;
  for (final entry in bundle.listSync(recursive: true)) {
    if (entry is! File) continue;
    final target = File(
      '${stage.path}\\${entry.path.substring(bundle.path.length + 1)}',
    );
    target.parent.createSync(recursive: true);
    entry.copySync(target.path);
    files++;
  }
  stdout.writeln('  bundle: $files files');
}

/// Copies the audio.cpp libraries beside the executable.
///
/// From a directory rather than a download: audio.cpp's Windows releases
/// contain statically linked executables and no `audiocpp_c.dll`, so the
/// shared library this app loads through FFI exists only if it is built from
/// source. The release workflow builds it; a developer points at their own
/// build directory.
void _addAudioCpp(Directory stage, String? dir) {
  final sep = Platform.pathSeparator;
  final candidates = [
    if (dir != null && dir.trim().isNotEmpty) dir.trim(),
    r'C:\dev\voicelab-runtime',
    '${Platform.environment['LOCALAPPDATA']}${sep}PopupBits${sep}runtime',
  ];

  for (final candidate in candidates) {
    final source = Directory(candidate);
    if (!File('$candidate${sep}audiocpp_c.dll').existsSync()) continue;

    var taken = 0;
    for (final entry in source.listSync().whereType<File>()) {
      if (!entry.path.endsWith('.dll')) continue;
      final leaf = entry.path.split(sep).last;
      // Its ggml backends travel with it; the sherpa ones come from their own
      // release and would otherwise be overwritten by a stale copy here.
      if (leaf == 'onnxruntime.dll' || leaf.startsWith('sherpa-onnx')) continue;
      entry.copySync('${stage.path}$sep$leaf');
      taken++;
      stdout.writeln('  $leaf  ${_size(entry.lengthSync())}');
    }
    if (taken > 0) return;
  }

  throw StateError(
    'No audiocpp_c.dll in any of:\n${candidates.map((c) => "  $c").join("\n")}'
    '\n\naudio.cpp publishes no shared library, so build one:\n'
    '  git clone https://github.com/0xShug0/audio.cpp\n'
    '  cmake -B build -DCMAKE_BUILD_TYPE=Release audio.cpp\n'
    '  cmake --build build --target audiocpp_c --config Release\n'
    'then pass --audiocpp-dir <that build\'s output>.',
  );
}

/// Fetches the sherpa-onnx libraries, which are published as a release.
///
/// Beside the executable, not in a subfolder: that is the first place the app
/// looks, and it is where Windows resolves a dependent DLL from. ONNX Runtime
/// in particular has to sit next to the sherpa library, or a stray copy
/// elsewhere on the system wins the search order and crashes in native code.
Future<void> _addSherpa(
  Directory stage,
  Directory out,
  String sherpa,
) async {
  await _unpack(
    stage: stage,
    cacheDir: out,
    name: 'sherpa-onnx-$sherpa-win-x64-shared-MT-Release-no-tts-lib.tar.bz2',
    url: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/$sherpa/'
        'sherpa-onnx-$sherpa-win-x64-shared-MT-Release-no-tts-lib.tar.bz2',
    wanted: (name) =>
        name == 'sherpa-onnx-c-api.dll' || name == 'onnxruntime.dll',
    unpackTar: true,
  );
}

Future<void> _unpack({
  required Directory stage,
  required Directory cacheDir,
  required String name,
  required String url,
  required bool Function(String) wanted,
  required bool unpackTar,
}) async {
  final cached = File('${cacheDir.path}\\cache\\$name');
  if (!cached.existsSync()) {
    stdout.writeln('downloading $name…');
    cached.parent.createSync(recursive: true);
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw StateError('$url returned HTTP ${response.statusCode}');
    }
    cached.writeAsBytesSync(response.bodyBytes);
  }

  final bytes = cached.readAsBytesSync();
  final archive = unpackTar
      ? TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes))
      : ZipDecoder().decodeBytes(bytes);

  var taken = 0;
  for (final entry in archive.files) {
    final leaf = entry.name.split('/').last;
    if (!entry.isFile || !wanted(leaf)) continue;
    File('${stage.path}\\$leaf').writeAsBytesSync(entry.content as List<int>);
    taken++;
    stdout.writeln('  $leaf  ${_size(entry.size)}');
  }
  if (taken == 0) {
    throw StateError('$name held none of the libraries expected. It has: '
        '${archive.files.take(20).map((f) => f.name).join(", ")}');
  }
}

/// Copies the notices a redistributed build is obliged to carry.
void _addDocuments(Directory stage) {
  for (final name in ['LICENSE', 'THIRD-PARTY-NOTICES.md']) {
    final source = File(name);
    if (!source.existsSync()) {
      throw StateError('$name is missing. The libraries in this package are '
          'redistributed under licences that require their notices.');
    }
    source.copySync('${stage.path}\\$name');
  }
  stdout.writeln('  LICENSE, THIRD-PARTY-NOTICES.md');
}

/// Fetches the full licence text of every library this redistributes.
///
/// Apache-2.0 asks that recipients be given a copy of the licence, not just
/// its name, and MIT that the notice travel with the software. Flutter's own
/// licence page covers the Dart packages; nothing covers the native libraries
/// but this.
Future<void> _addLicenceTexts(Directory stage) async {
  const sources = {
    'audio.cpp-Apache-2.0.txt':
        'https://raw.githubusercontent.com/0xShug0/audio.cpp/main/LICENSE',
    'sherpa-onnx-Apache-2.0.txt':
        'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/LICENSE',
    'onnxruntime-MIT.txt':
        'https://raw.githubusercontent.com/microsoft/onnxruntime/main/LICENSE',
  };

  final dir = Directory('${stage.path}\\licenses')..createSync();
  for (final entry in sources.entries) {
    final response = await http.get(Uri.parse(entry.value));
    if (response.statusCode != 200) {
      throw StateError('Could not fetch ${entry.value} — HTTP '
          '${response.statusCode}. A release may not ship these libraries '
          'without their licence text.');
    }
    File('${dir.path}\\${entry.key}').writeAsBytesSync(response.bodyBytes);
  }
  stdout.writeln('  licenses/: ${sources.length} files');
}

void _zip(Directory stage, File zip) {
  final archive = Archive();
  final root = stage.path.split(Platform.pathSeparator).last;
  for (final entry in stage.listSync(recursive: true).whereType<File>()) {
    final relative = entry.path
        .substring(stage.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    final bytes = entry.readAsBytesSync();
    archive.addFile(ArchiveFile('$root/$relative', bytes.length, bytes));
  }
  zip.writeAsBytesSync(ZipEncoder().encode(archive));
}

String _size(int bytes) => bytes >= 1048576
    ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).round()} KB';
