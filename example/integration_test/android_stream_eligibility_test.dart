import 'render_append_stages_test.dart' show registerAppendStageTest;
import 'render_performance_test.dart' show registerRenderFrameTest;

void main() {
  const layout = String.fromEnvironment(
    'RENDER_LAYOUT',
    defaultValue: 'sliver',
  );
  if (layout != 'sliver' && layout != 'paged') {
    throw ArgumentError.value(layout, 'RENDER_LAYOUT');
  }
  registerAppendStageTest(compareEligibility: true);
  registerRenderFrameTest(
    compareEligibility: true,
    measuredLayout: layout,
    prefillParts: 32,
    trials: 2,
  );
}
