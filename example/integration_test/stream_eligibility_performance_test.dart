import 'render_append_stages_test.dart' show registerAppendStageTest;
import 'render_performance_test.dart' show registerRenderFrameTest;

void main() {
  registerAppendStageTest(compareEligibility: true);
  registerRenderFrameTest(compareEligibility: true);
}
