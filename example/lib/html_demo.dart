import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

/// Demo page showing HTML tag rendering
class HtmlDemo extends StatefulWidget {
  const HtmlDemo({
    super.key,
    this.styleSheet,
  });

  final MarkdownStyleSheet? styleSheet;

  @override
  State<HtmlDemo> createState() => _HtmlDemoState();
}

class _HtmlDemoState extends State<HtmlDemo> {
  bool _enableHtml = true;
  bool _isStreaming = false;
  StreamController<String>? _streamController;

  static const String _htmlContent = '''
\n\n根据您**气阴两虚兼虚火、脾胃偏弱**的舌象和体质特征，为您推荐以下常用中成药（按核心功效分类），并附搭配建议与注意事项：\n\n---\n\n### 📋 **对症中成药推荐**\n| 中成药 | 核心功效 | 适用症状匹配 | 用法用量 | 注意事项 |\n|--------|----------|--------------|----------|----------|\n| **生脉饮** | 益气养阴、生津敛汗 | 气阴两虚（乏力、口干、舌红少苔） | 10ml/次，2 次/日 | 感冒发热时停用 |\n| **参苓白术散** | 健脾益气、渗湿止泻 | 脾虚湿滞（便溏、舌苔厚腻） | 6g/次，2-3 次/日 | 阴虚火旺者减量 |\n| **六味地黄丸** | 滋阴补肾、清热降火 | 肾阴虚（舌中裂纹、咽干、虚烦） | 8 丸/次，2 次/日 | 脾胃虚寒者慎用 |\n| **阴虚胃痛颗粒** | 养阴益胃、缓急止痛 | 胃阴不足（舌苔剥落、胃部隐痛） | 1 袋/次，3 次/日 | 忌辛辣生冷 |\n\n---\n\n### 💡 **搭配使用建议**\n| 组合方案 | 适用阶段 | 功效侧重 |\n|----------|----------|----------|\n| **生脉饮 + 参苓白术散** | 气阴两虚兼脾虚湿困 | 益气养阴为主，健脾化湿为辅 |\n| **六味地黄丸 + 阴虚胃痛颗粒** | 阴虚火旺明显（舌红裂纹深） | 滋补肾阴，清胃火，改善舌苔剥落 |\n\n---\n\n### ⚠️ **关键注意事项**\n1. **辨证前提**：\n   - 若舌苔仍厚腻、大便黏滞，**先健脾化湿**（用参苓白术散），暂缓滋阴药\n   - 若咽干、心烦、舌红少苔突出，**侧重滋阴降火**（六味地黄丸 + 生脉饮）\n2. **禁忌与配伍**：\n   - ❌ 避免与温燥补药（如附子理中丸、金匮肾气丸）同用\n   - ⚠️ 服药期间忌辛辣、油腻、生冷（与您药膳禁忌一致）\n   - 💡 中成药与西药间隔 1 小时服用，避免相互作用\n3. **疗程与反馈**：\n   - 连续服用 2 周后评估舌象：若舌苔渐匀、裂纹变浅，可维持；若出现腹胀/便溏，减少滋阴药量\n\n---\n\n### 📝 **综合调理提醒**\n- **中成药是辅助**：不能替代药膳、作息调整等基础调理\n- **动态调整**：建议每 2 周复诊中医师，根据舌象变化调整用药\n- **穴位配合**：继续按摩 **足三里（健脾）、三阴交（滋阴）、太溪（补肾阴）**，增强药效\n\n---\n\n### 🔍 **快速自测**\n| 症状 | 推荐中成药 |\n|------|------------|\n| 乏力 + 口干 + 舌红少苔 | 生脉饮 |\n| 便溏 + 舌苔厚腻 + 腹胀 | 参苓白术散 |\n| 咽干 + 舌中裂纹 + 心烦 | 六味地黄丸 |\n| 胃部隐痛 + 舌苔剥落 | 阴虚胃痛颗粒 |\n\n> 注：中成药需在中医师辨证指导下使用，若服药后出现不适（如腹泻、上火），请立即停用并就医。您目前最困扰的症状是口干、乏力还是胃部不适？可进一步细化推荐。", "authorId": "", "metadata": {"selectBtnList": []}, "mimeType": "", "createdAt": "2026-08-15T09:06:05.490", "sessionId": "d9d0caf6-58bb-4d92-a37b-313b0a14816d", "thinkTime": 2, "authorName": "", "isSendByMe": false, "sendStatus": 0, "messageType": 0, "parentMsgId": "9a8d8c8e-be6b-4e1e-aece-b2f9d1bb504e", "businessType": "none", "deepThinkStr": "用户现在想让我推荐中成药。让我先回顾一下整个对话的上下文，看看用户的需求和情况。\n\n用户之前上传了舌苔照，分析显示舌质淡红有裂纹，舌苔薄白部分剥落，面色偏红，唇色偏深红偏干。结合之前的对话记忆，用户体质是气阴两虚兼有虚火，脾胃偏弱。我已经给过一周药膳建议和老鸭汤的做法，还讨论了玉竹的替代方案。\n\n现在用户问中成药推荐，我需要基于这个体质来推荐合适的药物。不过中医用药讲究辨证论治，中成药虽然方便，但也需要根据具体症状来选择。\n\n从舌象和症状来看，用户主要是气阴两虚，可能有脾虚和阴虚火旺的表现。舌中裂纹提示胃阴不足，舌苔剥落也是阴虚的表现，面色偏红和唇干可能跟虚火有关。\n\n我需要推荐一些既能益气养阴，又能兼顾健脾和清虚火的中成药。常见的如生脉饮适合气阴两虚，但可能滋阴力度不够；六味地黄丸是滋阴名方，但偏于补肾阴；参苓白术散健脾祛湿，但滋阴力弱。\n\n我觉得可能需要一个组合方案，或者推荐一个比较全面的药物。让我想想哪些中成药比较符合用户的体质特点。\n\n另外，用户之前对药膳调理有不错的反应，中成药可以作为辅助，但不能替代生活方式调理。我需要提醒用户中成药需要在医师指导下使用，因为中医讲究辨证论治，同样症状可能体质不同用药就不同。\n\n好的，我准备给用户推荐适合的中成药，并说明使用方法和注意事项。
''';

  /// Splits the demo content into word-level chunks with their trailing
  /// whitespace, approximating how a token stream would arrive.
  static List<String> _chunkContent(String content) {
    return RegExp(r'\S+\s*')
        .allMatches(content)
        .map((match) => match[0]!)
        .toList();
  }

  /// Streams the demo content chunk by chunk to simulate live output.
  Future<void> _startStreaming() async {
    if (_isStreaming) return;

    final controller = StreamController<String>();
    setState(() {
      _isStreaming = true;
      _streamController = controller;
    });

    for (final chunk in _chunkContent(_htmlContent)) {
      if (!mounted || controller.isClosed) break;
      controller.add(chunk);
      await Future.delayed(const Duration(milliseconds: 40));
    }

    if (mounted) {
      setState(() => _isStreaming = false);
      await controller.close();
    }
  }

  /// Stops the active stream and returns to the static view.
  void _stopStreaming() {
    _streamController?.close();
    setState(() {
      _streamController = null;
      _isStreaming = false;
    });
  }

  @override
  void dispose() {
    _streamController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTML Tags Demo'),
        actions: [
          Row(
            children: [
              const Text('HTML'),
              Switch(
                value: _enableHtml,
                onChanged: (value) => setState(() => _enableHtml = value),
              ),
            ],
          ),
          IconButton(
            tooltip: _isStreaming ? 'Stop streaming' : 'Simulate streaming',
            icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
            onPressed: _isStreaming ? _stopStreaming : _startStreaming,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isStreaming) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _streamController == null
                  ? SmoothMarkdown(
                      data: _htmlContent,
                      styleSheet: widget.styleSheet,
                      config: MarkdownConfig(enableHtml: _enableHtml),
                    )
                  : StreamMarkdown(
                      stream: _streamController!.stream,
                      styleSheet: widget.styleSheet,
                      config: MarkdownConfig(enableHtml: _enableHtml),
                      loadingWidget:
                          const Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
