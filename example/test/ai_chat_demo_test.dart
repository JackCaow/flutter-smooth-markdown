import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_smooth_markdown_example/ai_chat_demo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DeepSeek request uses the documented endpoint and thinking format', () {
    final request = buildDeepSeekChatRequest(
      prompt: 'Hello',
      apiKey: 'test-key',
      model: 'deepseek-flash',
      enableThinking: true,
    );

    expect(request.method, 'POST');
    expect(request.url.toString(), 'https://api.deepseek.com/chat/completions');
    expect(request.headers['Authorization'], 'Bearer test-key');
    expect(request.headers['Content-Type'], 'application/json');

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['model'], 'deepseek-flash');
    expect(body['stream'], isTrue);
    expect(body['thinking'], {'type': 'enabled'});
    expect(body.containsKey('enable_thinking'), isFalse);
    expect((body['messages'] as List).last, {
      'role': 'user',
      'content': 'Hello',
    });

    final withoutThinking = buildDeepSeekChatRequest(
      prompt: 'Hello',
      apiKey: 'test-key',
      model: 'deepseek-v4-pro',
      enableThinking: false,
    );
    final otherBody = jsonDecode(withoutThinking.body) as Map<String, dynamic>;
    expect(otherBody['model'], 'deepseek-v4-pro');
    expect(otherBody['thinking'], {'type': 'disabled'});
  });

  testWidgets('chat opens without demo messages and keeps prompts in a menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AIChatDemo()));
    await tester.pumpAndSettle();

    expect(find.text('AI Chat'), findsOneWidget);
    expect(find.text('模拟模式'), findsOneWidget);
    expect(find.text('发送消息，或点击右上角快捷提示词'), findsOneWidget);
    expect(find.byTooltip('快捷提示词'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('API 设置'));
    await tester.pumpAndSettle();
    expect(find.text('DeepSeek API Key'), findsOneWidget);
    expect(find.text('DeepSeek Flash'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('快捷提示词'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thinking'), findsOneWidget);
  });

  testWidgets('configured DeepSeek key selects the real API by default', (
    tester,
  ) async {
    dotenv.testLoad(fileInput: 'DEEPSEEK_API_KEY=test-key');
    await tester.pumpWidget(const MaterialApp(home: AIChatDemo()));

    expect(find.text('deepseek-flash (思考)'), findsOneWidget);
  });
}
