import 'dart:io';
import 'dart:math' as math;

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final config = input.config.code;
    final os = config.targetOS;
    final arch = config.targetArchitecture;
    final target = rustTarget(config);
    final core = input.packageRoot.resolve('rust-core/');
    // Rust's LLVM strip can emit an unaligned Mach-O string table with
    // recent Apple linkers. Let Flutter/Xcode strip/sign the final bundle.
    final environment = <String, String>{
      // Flutter prioritizes parse/highlight throughput. Select optimization at
      // build time for the bundled native asset.
      'CARGO_PROFILE_RELEASE_OPT_LEVEL': '3',
      if (os == OS.iOS || os == OS.macOS) 'CARGO_PROFILE_RELEASE_STRIP': 'none',
    };
    if (os == OS.android) {
      final compiler = config.cCompiler;
      if (compiler == null)
        throw StateError('Android NDK compiler is required');
      final prefix = switch (arch) {
        Architecture.arm => 'armv7a-linux-androideabi',
        Architecture.arm64 => 'aarch64-linux-android',
        Architecture.ia32 => 'i686-linux-android',
        Architecture.x64 => 'x86_64-linux-android',
        _ => throw UnsupportedError('Android $arch'),
      };
      final linker = compiler.compiler.resolve(
        '$prefix${config.android.targetNdkApi}-clang${Platform.isWindows ? '.cmd' : ''}',
      );
      environment['CARGO_TARGET_${target.toUpperCase().replaceAll('-', '_')}_LINKER'] =
          linker.toFilePath();
    } else if (os == OS.iOS || os == OS.macOS) {
      final sdk = os == OS.macOS ? 'macosx' : config.iOS.targetSdk.type;
      final result = await Process.run('xcrun', [
        '--sdk',
        sdk,
        '--show-sdk-path',
      ]);
      if (result.exitCode != 0) throw StateError('${result.stderr}');
      environment['SDKROOT'] = '${result.stdout}'.trim();
      // Flutter supplies 13 as its generic macOS hook target even for apps
      // supporting macOS 12. The core uses APIs available on this lower floor.
      final deployment = os == OS.macOS
          ? math.min(config.macOS.targetVersion, 12)
          : config.iOS.targetVersion;
      environment[os == OS.macOS
              ? 'MACOSX_DEPLOYMENT_TARGET'
              : 'IPHONEOS_DEPLOYMENT_TARGET'] =
          '$deployment.0';
    }
    final cargoOutput = input.outputDirectory.resolve('cargo/');
    final result = await Process.run('cargo', [
      'build',
      '--locked',
      '--offline',
      '--release',
      '--features',
      'flutter-compact-ast',
      '--target',
      target,
      '--target-dir',
      cargoOutput.toFilePath(),
      '--manifest-path',
      core.resolve('Cargo.toml').toFilePath(),
    ], environment: environment);
    if (result.exitCode != 0) {
      throw StateError(
        'Rust build failed for $target. Install Rust and run '
        '`rustup target add $target`.\n${result.stdout}\n${result.stderr}',
      );
    }
    final name = os == OS.windows
        ? 'smooth_markdown_rust.dll'
        : (os == OS.macOS || os == OS.iOS)
        ? 'libsmooth_markdown_rust.dylib'
        : 'libsmooth_markdown_rust.so';
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/rust/bindings.dart',
        linkMode: DynamicLoadingBundled(),
        file: cargoOutput.resolve('$target/release/$name'),
      ),
    );
    output.dependencies.addAll([
      core.resolve('Cargo.toml'),
      core.resolve('Cargo.lock'),
      core.resolve('UPSTREAM'),
      ...Directory.fromUri(
        core.resolve('src/'),
      ).listSync(recursive: true).whereType<File>().map((file) => file.uri),
    ]);
  });
}

/// Maps the SDK's target (including iOS simulator) to a Rust target triple.
String rustTarget(CodeConfig config) {
  final arch = config.targetArchitecture;
  return switch (config.targetOS) {
    OS.macOS => switch (arch) {
      Architecture.arm64 => 'aarch64-apple-darwin',
      Architecture.x64 => 'x86_64-apple-darwin',
      _ => throw UnsupportedError('macOS $arch'),
    },
    OS.iOS => switch ((arch, config.iOS.targetSdk)) {
      (Architecture.arm64, IOSSdk.iPhoneOS) => 'aarch64-apple-ios',
      (Architecture.arm64, IOSSdk.iPhoneSimulator) => 'aarch64-apple-ios-sim',
      (Architecture.x64, IOSSdk.iPhoneSimulator) => 'x86_64-apple-ios',
      _ => throw UnsupportedError('iOS $arch ${config.iOS.targetSdk}'),
    },
    OS.android => switch (arch) {
      Architecture.arm => 'armv7-linux-androideabi',
      Architecture.arm64 => 'aarch64-linux-android',
      Architecture.ia32 => 'i686-linux-android',
      Architecture.x64 => 'x86_64-linux-android',
      _ => throw UnsupportedError('Android $arch'),
    },
    OS.linux => switch (arch) {
      Architecture.arm64 => 'aarch64-unknown-linux-gnu',
      Architecture.x64 => 'x86_64-unknown-linux-gnu',
      _ => throw UnsupportedError('Linux $arch'),
    },
    OS.windows => switch (arch) {
      Architecture.arm64 => 'aarch64-pc-windows-msvc',
      Architecture.x64 => 'x86_64-pc-windows-msvc',
      _ => throw UnsupportedError('Windows $arch'),
    },
    _ => throw UnsupportedError('Rust core target ${config.targetOS} $arch'),
  };
}
