import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) => writeResponseData(
    data,
    destinationDirectory: 'build/core-performance',
    testOutputFilename: switch (data) {
      {'sustained_render_cell': final String cell} =>
        'profile-sustained-render-$cell',
      {'compare_stream_eligibility': true} => 'profile-stream-eligibility',
      {'render_append_stages': _} => 'profile-render-append-stages',
      {'render_comparison': _} => 'profile-render',
      {'sustained_comparison': _} => 'profile-sustained',
      {'incremental_comparison': _} => 'profile-incremental',
      {'stages': _} => 'profile-stages',
      _ => 'profile-comparison',
    },
  ),
);
