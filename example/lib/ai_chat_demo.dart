import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:http/http.dart' as http;

/// Builds the optional DeepSeek request used by this example app.
http.Request buildDeepSeekChatRequest({
  required String prompt,
  required String apiKey,
  required String model,
  required bool enableThinking,
}) {
  final request = http.Request(
    'POST',
    Uri.parse('https://api.deepseek.com/chat/completions'),
  );
  request.headers.addAll({
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  });
  request.body = jsonEncode({
    'model': model,
    'messages': [
      {
        'role': 'system',
        'content': '''你是一个 AI 助手。在回答时，请适当使用以下格式：

1. 使用 <artifact identifier="id" type="code" language="lang" title="title">...</artifact> 包裹代码制品
2. 使用标准 Markdown 格式

请确保回答内容丰富、格式清晰。''',
      },
      {'role': 'user', 'content': prompt},
    ],
    'stream': true,
    'thinking': {'type': enableThinking ? 'enabled' : 'disabled'},
  });
  return request;
}

/// AI Chat Demo with optional DeepSeek API integration
///
/// Features:
/// - Optional real API calls to DeepSeek models
/// - Quick prompts to test all AI plugins (thinking, artifact, tool_call)
/// - Streaming response support
/// - Custom parser plugins for AI chat scenarios
class AIChatDemo extends StatefulWidget {
  const AIChatDemo({super.key});

  @override
  State<AIChatDemo> createState() => _AIChatDemoState();
}

class _AIChatDemoState extends State<AIChatDemo> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isStreaming = false;
  bool _isDarkMode = false;
  bool _useRealAPI = true;
  bool _enableThinking = true; // 开启思考模式
  late String _apiKey;
  String _selectedModel = 'deepseek-flash';

  // Parser with AI chat plugins
  late final ParserPluginRegistry _pluginRegistry;

  @override
  void initState() {
    super.initState();
    _apiKey = dotenv.isInitialized ? (dotenv.env['DEEPSEEK_API_KEY'] ?? '') : '';
    _initPlugins();
  }

  void _initPlugins() {
    _pluginRegistry = ParserPluginRegistry();
    _pluginRegistry.register(const ThinkingPlugin());
    _pluginRegistry.register(const ArtifactPlugin());
    _pluginRegistry.register(const ToolCallPlugin());
  }

  void _loadWelcomeMessage() {
    _messages.add(ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: '''
# 🤖 AI Chat

本页面可连接 **DeepSeek**，也可用模拟响应测试以下 AI 特性解析：

## 支持的 AI 格式

1. **Thinking Block** - AI 思考过程
2. **Artifact Block** - 代码/文档制品
3. **Tool Call Block** - 工具调用

点击右上角的 **快捷提示词** 菜单来测试各种功能。

---

💡 **提示**: 未配置 DeepSeek API Key 时使用模拟响应。点击右上角设置图标可配置 Key 和切换模式。
''',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  // Quick prompts for testing all AI plugin cases
  List<QuickPrompt> get _quickPrompts => [
    QuickPrompt(
      label: '🧠 Thinking',
      description: '测试思考块解析',
      prompt: '演示 thinking block',
      mockResponse: _getMockThinkingResponse(),
    ),
    QuickPrompt(
      label: '📦 Artifact',
      description: '测试制品块解析',
      prompt: '演示 artifact block',
      mockResponse: _getMockArtifactResponse(),
    ),
    QuickPrompt(
      label: '🔧 Tool Call',
      description: '测试工具调用解析',
      prompt: '演示 tool call block',
      mockResponse: _getMockToolCallResponse(),
    ),
    QuickPrompt(
      label: '🎯 All-in-One',
      description: '测试所有格式',
      prompt: '演示所有 AI 格式',
      mockResponse: _getMockAllInOneResponse(),
    ),
    QuickPrompt(
      label: '💻 Code',
      description: '生成代码示例',
      prompt: '写一个 Flutter Widget 示例',
      mockResponse: _getMockCodeResponse(),
    ),
    QuickPrompt(
      label: '📊 Table',
      description: '生成表格',
      prompt: '对比 Flutter 和 React Native',
      mockResponse: _getMockTableResponse(),
    ),
  ];

  String _getMockThinkingResponse() {
    return '''
<thinking>
让我分析一下用户的问题...

首先，用户想要了解 thinking block 的解析。

我需要：
1. 解释 thinking block 的用途
2. 展示正确的语法格式
3. 说明何时使用

thinking block 主要用于展示 AI 的推理过程，让用户理解 AI 是如何得出结论的。
</thinking>

# Thinking Block 演示

Thinking block 用于展示 AI 的 **内部推理过程**。

## 语法格式

支持两种格式：

1. XML 风格: `<thinking>...</thinking>`
2. 简写: `<think>...</think>`

## 使用场景

- 展示复杂问题的分析过程
- 让用户理解 AI 的推理逻辑
- 提高回答的透明度

上面的折叠块就是一个 thinking block 示例！点击可以展开查看。
''';
  }

  String _getMockArtifactResponse() {
    return '''
# Artifact Block 演示

Artifact 用于展示 **可复用的代码或文档制品**。

## 代码制品示例

<artifact identifier="hello-dart" type="code" language="dart" title="Hello World">
void main() {
  print('Hello, World!');

  final message = 'This is an artifact!';
  print(message);
}
</artifact>

## 文档制品示例

<artifact id="readme" type="document" title="项目说明">
# 项目名称

这是一个示例项目。

## 功能特性

- 特性 1
- 特性 2
- 特性 3
</artifact>

## Mermaid 图表示例

<artifact id="flow" type="mermaid" title="流程图">
graph TD
    A[开始] --> B{判断}
    B -->|是| C[执行]
    B -->|否| D[结束]
    C --> D
</artifact>

Artifact 支持多种类型：`code`, `document`, `html`, `svg`, `component`, `mermaid`
''';
  }

  String _getMockToolCallResponse() {
    return '''
# Tool Call Block 演示

Tool Call 用于展示 **AI 工具调用**。

## 搜索工具调用

<tool_use>
<tool_name>web_search</tool_name>
<tool_id>search_001</tool_id>
<input>
query: "Flutter Smooth Markdown"
limit: 10
</input>
</tool_use>

## 代码执行工具

<tool_use>
<tool_name>code_interpreter</tool_name>
<tool_id>exec_002</tool_id>
<input>
language: "python"
code: "print(sum(range(1, 101)))"
</input>
</tool_use>

## 文件操作工具

<tool_use>
<tool_name>file_write</tool_name>
<input>
path: "/tmp/test.txt"
content: "Hello World"
</input>
</tool_use>

Tool Call 块会显示工具名称、参数和执行状态。
''';
  }

  String _getMockAllInOneResponse() {
    return '''
<thinking>
用户想要看到所有 AI 格式的综合演示。

我需要：
1. 先展示一个 thinking block
2. 然后展示 artifact
3. 最后展示 tool call
4. 加上一些普通的 markdown 内容

让我按顺序组织这些内容...
</thinking>

# 🎯 AI 格式综合演示

这是一个包含所有 AI 特殊格式的完整示例。

## 1️⃣ 思考过程

上面的折叠块展示了 AI 的思考过程。

## 2️⃣ 代码制品

<artifact identifier="demo-widget" type="code" language="dart" title="Flutter Widget">
class DemoWidget extends StatelessWidget {
  const DemoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Hello from Artifact!'),
    );
  }
}
</artifact>

## 3️⃣ 工具调用

<tool_use>
<tool_name>analyze_code</tool_name>
<tool_id>analysis_001</tool_id>
<input>
file: "demo_widget.dart"
checks: ["lint", "format", "performance"]
</input>
</tool_use>

## 4️⃣ 普通 Markdown

当然，我们也支持所有标准 **Markdown** 语法：

- ✅ 粗体、*斜体*、`行内代码`
- ✅ 列表和任务清单
- ✅ 引用块和代码块
- ✅ 表格和图片

> 这是一个引用块示例
>
> — AI Assistant

```dart
// 普通代码块示例
void main() => print('Standard code block');
```

---

**总结**: 所有格式都已成功解析和渲染！ 🎉
''';
  }

  String _getMockCodeResponse() {
    return '''
<thinking>
用户想要一个 Flutter Widget 示例。

让我创建一个实用的、可复制的 Widget：
- 包含基础结构
- 展示常用模式
- 代码清晰易懂
</thinking>

# Flutter Widget 示例

这是一个可复用的卡片组件：

<artifact identifier="user-card" type="code" language="dart" title="UserCard Widget">
import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.onTap,
  });

  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Text(name[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
</artifact>

## 使用方法

```dart
UserCard(
  name: 'John Doe',
  email: 'john@example.com',
  avatarUrl: 'https://example.com/avatar.png',
  onTap: () => print('Card tapped!'),
)
```

这个组件支持：
- ✅ 头像显示（支持网络图片或首字母）
- ✅ 点击回调
- ✅ 圆角卡片设计
- ✅ Material Design 风格
''';
  }

  String _getMockTableResponse() {
    return '''
<thinking>
用户想要对比 Flutter 和 React Native。

我需要从多个维度进行对比：
- 性能
- 开发体验
- 社区生态
- 学习曲线
- 适用场景
</thinking>

# Flutter vs React Native 对比

## 综合对比表

| 特性 | Flutter | React Native |
|------|---------|--------------|
| **开发语言** | Dart | JavaScript/TypeScript |
| **渲染引擎** | Skia (自绘) | 原生组件 |
| **性能** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **热重载** | ✅ 极快 | ✅ 快 |
| **UI 一致性** | ✅ 完全一致 | ⚠️ 平台差异 |
| **原生功能** | 通过插件 | 通过桥接 |
| **包大小** | ~5MB | ~7MB |
| **学习曲线** | 中等 | 较低 (Web 背景) |

## 详细分析

### 🚀 性能

| 场景 | Flutter | React Native |
|------|:-------:|:------------:|
| 列表滚动 | 60 FPS | 55-60 FPS |
| 动画 | 流畅 | 可能卡顿 |
| 启动时间 | 快 | 中等 |
| 内存占用 | 较低 | 中等 |

### 🛠️ 开发体验

| 方面 | Flutter | React Native |
|------|---------|--------------|
| IDE 支持 | VS Code, Android Studio | VS Code, WebStorm |
| 调试工具 | DevTools | Chrome DevTools |
| 测试框架 | 内置完善 | Jest + Testing Library |
| 文档质量 | 优秀 | 良好 |

## 推荐场景

**选择 Flutter:**
- 需要高度一致的 UI
- 性能要求高
- 复杂动画需求
- 新项目从零开始

**选择 React Native:**
- 团队有 Web 背景
- 需要快速原型
- 大量复用 Web 代码
- 已有 React 生态

---

> 两者都是优秀的跨平台方案，选择取决于团队技术栈和项目需求。
''';
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    _controller.clear();
    _scrollToBottom();

    // Find matching quick prompt or generate generic response
    final matchingPrompt = _quickPrompts.firstWhere(
      (p) => text.contains(p.prompt) || p.prompt.contains(text),
      orElse: () => QuickPrompt(
        label: '',
        description: '',
        prompt: text,
        mockResponse: _getGenericResponse(text),
      ),
    );

    if (_useRealAPI && _apiKey.isNotEmpty) {
      _callDeepSeekAPI(text);
    } else {
      _simulateStreamResponse(matchingPrompt.mockResponse);
    }
  }

  String _getGenericResponse(String prompt) {
    return '''
<thinking>
分析用户的问题: "$prompt"

这是一个通用回复，因为没有匹配到预设的快捷提示词。
</thinking>

# 回复

您好！您的问题是: **$prompt**

这是一个模拟回复。要获得真实的 AI 回复，请：

1. 点击右上角设置图标 ⚙️
2. 输入您的 DeepSeek API Key
3. 开启 "使用真实 API" 开关

---

您也可以尝试右上角的 **快捷提示词** 菜单来测试各种 AI 格式解析功能！
''';
  }

  Future<void> _callDeepSeekAPI(String prompt) async {
    final streamController = StreamController<String>();

    setState(() {
      _isStreaming = true;
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        stream: streamController.stream,
        isStreaming: true,
      ));
    });

    _scrollToBottom();

    try {
      final request = buildDeepSeekChatRequest(
        prompt: prompt,
        apiKey: _apiKey,
        model: _selectedModel,
        enableThinking: _enableThinking,
      );

      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        bool isInThinking = false;

        await for (final line in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') continue;

            try {
              final json = jsonDecode(data);
              final choices = json['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'];

                // 处理思考内容 (reasoning_content)
                final reasoningContent = delta['reasoning_content'] as String?;
                if (reasoningContent != null && reasoningContent.isNotEmpty) {
                  if (!isInThinking) {
                    isInThinking = true;
                    streamController.add('<thinking>\n');
                  }
                  streamController.add(reasoningContent);
                }

                // 处理正常内容
                final content = delta['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  // 如果之前在思考模式，先关闭 thinking 标签
                  if (isInThinking) {
                    isInThinking = false;
                    streamController.add('\n</thinking>\n\n');
                  }
                  streamController.add(content);
                }
              }
            } catch (e) {
              // 忽略解析错误
            }
          }
        }

        // 如果思考模式没有正常关闭
        if (isInThinking) {
          streamController.add('\n</thinking>\n\n');
        }

        await streamController.close();

        if (mounted) {
          setState(() {
            _isStreaming = false;
          });
        }
      } else {
        await streamController.close();
        _handleAPIError('API Error: ${response.statusCode}');
      }
    } catch (e) {
      await streamController.close();
      _handleAPIError('Network Error: $e');
    }
  }

  void _handleAPIError(String error) {
    setState(() {
      _messages.last = _messages.last.copyWith(
        content: '⚠️ **错误**: $error\n\n请检查 API Key 配置或网络连接。',
        isStreaming: false,
      );
      _isStreaming = false;
    });
  }

  Future<void> _simulateStreamResponse(String response) async {
    final streamController = StreamController<String>();

    setState(() {
      _isStreaming = true;
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        stream: streamController.stream,
      ));
    });

    _scrollToBottom();

    // Simulate streaming with realistic typing speed
    const chunkSize = 5;
    for (var i = 0; i < response.length;) {
      if (!mounted) break;

      final end = (i + chunkSize).clamp(0, response.length);
      final chunk = response.substring(i, end);
      streamController.add(chunk);

      await Future.delayed(const Duration(milliseconds: 20));
      i = end;
    }

    await streamController.close();

    if (mounted) {
      setState(() {
        _isStreaming = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // DeepSeek Chat Completions API 支持的模型。
  static const List<Map<String, String>> _availableModels = [
    {'id': 'deepseek-flash', 'name': 'DeepSeek Flash'},
    {'id': 'deepseek-v4-pro', 'name': 'DeepSeek V4 Pro'},
  ];

  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('API 设置'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'DeepSeek API Key',
                    hintText: 'sk-...',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  controller: TextEditingController(text: _apiKey),
                  onChanged: (value) {
                    setState(() => _apiKey = value);
                  },
                ),
                const SizedBox(height: 16),

                // 模型选择
                const Text('选择模型', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedModel,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _availableModels.map((model) {
                    return DropdownMenuItem(
                      value: model['id'],
                      child: Text(model['name']!, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _selectedModel = value;
                      });
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 思考模式开关
                SwitchListTile(
                  title: const Text('启用思考模式'),
                  subtitle: const Text('显示 AI 的推理过程'),
                  value: _enableThinking,
                  onChanged: (value) {
                    setDialogState(() {
                      _enableThinking = value;
                    });
                    setState(() {});
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const Divider(),

                SwitchListTile(
                  title: const Text('使用真实 API'),
                  subtitle: const Text('关闭时使用模拟响应'),
                  value: _useRealAPI,
                  onChanged: (value) {
                    setDialogState(() {
                      _useRealAPI = value;
                    });
                    setState(() {});
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '未配置 Key 时使用模拟响应，可通过快捷提示词测试 Thinking、Artifact 和 Tool Call。输入 DeepSeek API Key 并开启真实 API 可获取在线回复。',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(_loadWelcomeMessage);
                  },
                  child: const Text('查看格式说明'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Chat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                _isStreaming
                    ? '正在输入...'
                    : (_useRealAPI && _apiKey.isNotEmpty
                        ? (_enableThinking
                            ? '$_selectedModel (思考)'
                            : _selectedModel)
                        : '模拟模式'),
                style: TextStyle(
                  fontSize: 12,
                  color: _isStreaming
                      ? Colors.blue
                      : (_useRealAPI && _apiKey.isNotEmpty
                          ? Colors.green
                          : Colors.orange),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<int>(
              icon: const Icon(Icons.bolt),
              tooltip: '快捷提示词',
              enabled: !_isStreaming,
              onSelected: (index) => _sendMessage(_quickPrompts[index].prompt),
              itemBuilder: (context) => List.generate(_quickPrompts.length, (index) {
                final prompt = _quickPrompts[index];
                return PopupMenuItem(
                  value: index,
                  child: Text('${prompt.label} · ${prompt.description}'),
                );
              }),
            ),
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              tooltip: '切换主题',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettings,
              tooltip: 'API 设置',
            ),
          ],
        ),
        body: Column(
          children: [
            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('发送消息，或点击右上角快捷提示词'))
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return AIChatBubble(
                    key: ValueKey(_messages[index].id),
                    message: _messages[index],
                    isDark: isDark,
                    pluginRegistry: _pluginRegistry,
                  );
                },
              ),
            ),

            // Input area
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF3A3A3C)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: '输入消息...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: _sendMessage,
                          enabled: !_isStreaming,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: _isStreaming
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              ),
                        color: _isStreaming ? Colors.grey : null,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isStreaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _isStreaming
                            ? null
                            : () => _sendMessage(_controller.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// Chat bubble widget with AI plugin support
class AIChatBubble extends StatefulWidget {
  const AIChatBubble({
    required this.message,
    required this.isDark,
    required this.pluginRegistry,
    super.key,
  });

  final ChatMessage message;
  final bool isDark;
  final ParserPluginRegistry pluginRegistry;

  @override
  State<AIChatBubble> createState() => _AIChatBubbleState();
}

class _AIChatBubbleState extends State<AIChatBubble>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            widget.message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!widget.message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: widget.message.isUser
                    ? (widget.isDark
                        ? const Color(0xFF0A84FF)
                        : const Color(0xFF007AFF))
                    : (widget.isDark
                        ? const Color(0xFF2C2C2E)
                        : Colors.white),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Render markdown with AI plugins
                  if (widget.message.stream != null)
                    StreamMarkdown(
                      stream: widget.message.stream!,
                      styleSheet: widget.message.isUser
                          ? _getUserStyleSheet()
                          : (widget.isDark
                              ? MarkdownStyleSheet.dark()
                              : MarkdownStyleSheet.light()),
                      useEnhancedComponents: !widget.message.isUser,
                      plugins: widget.pluginRegistry,
                    )
                  else
                    SmoothMarkdown(
                      data: widget.message.content,
                      enableCache: true,
                      useRepaintBoundary: true,
                      styleSheet: widget.message.isUser
                          ? _getUserStyleSheet()
                          : (widget.isDark
                              ? MarkdownStyleSheet.dark()
                              : MarkdownStyleSheet.light()),
                      useEnhancedComponents: !widget.message.isUser,
                      plugins: widget.pluginRegistry,
                    ),

                  // Timestamp
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(widget.message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.message.isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : (widget.isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  MarkdownStyleSheet _getUserStyleSheet() {
    return MarkdownStyleSheet(
      textStyle: const TextStyle(color: Colors.white, fontSize: 15),
      paragraphStyle: const TextStyle(color: Colors.white, fontSize: 15),
      h1Style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      h2Style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      h3Style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      inlineCodeStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        backgroundColor: Colors.black.withValues(alpha: 0.2),
        fontFamily: 'monospace',
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 30) {
      return '刚刚';
    } else if (diff.inMinutes < 1) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }
}

/// Quick prompt data model
class QuickPrompt {
  const QuickPrompt({
    required this.label,
    required this.description,
    required this.prompt,
    required this.mockResponse,
  });

  final String label;
  final String description;
  final String prompt;
  final String mockResponse;
}

/// Chat message data model
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.stream,
    this.isStreaming = false,
  });

  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final Stream<String>? stream;
  final bool isStreaming;

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    Stream<String>? stream,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      stream: stream ?? this.stream,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
