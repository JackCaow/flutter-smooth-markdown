# HTML 支持

Flutter Smooth Markdown 支持渲染一个安全白名单内的 HTML 标签。该功能默认**关闭**，需要通过 `MarkdownConfig(enableHtml: true)` 显式开启。

## 快速开始

```dart
SmoothMarkdown(
  data: '按 <kbd>Ctrl</kbd> + <kbd>C</kbd> 复制 <mark>高亮文本</mark>',
  config: const MarkdownConfig(enableHtml: true),
)
```

流式渲染（`StreamMarkdown`）与编辑器预览会自动继承该配置。

## 支持的标签

### 内联标签

| 标签 | 效果 |
|------|------|
| `<b>` / `<strong>` | **加粗** |
| `<i>` / `<em>` | *斜体* |
| `<u>` / `<ins>` | 下划线 |
| `<s>` / `<del>` / `<strike>` | ~~删除线~~ |
| `<mark>` | 高亮 |
| `<sub>` / `<sup>` | 下标 / 上标 |
| `<kbd>` | 键盘按键样式 |
| `<code>` | 行内代码（内容原样保留，不递归解析） |
| `<br>` / `<br/>` | 强制换行 |
| `<a href="..." title="...">` | 链接（复用 `onTapLink` 回调） |
| `<img src alt title width height>` | 图片（支持尺寸、网络缓存与 SVG） |
| `<font color="..." size="1-7">` | 文字颜色 / 传统字号 |
| `<span style="...">` | 安全样式子集（见下） |

### 块级标签

| 标签 | 效果 |
|------|------|
| `<div>` / `<p>` | 块容器，支持 `align` 属性 |
| `<center>` | 居中块 |
| `<blockquote>` | 引用块（复用 Markdown 引用样式） |
| `<hr>` / `<hr/>` | 分隔线（需独占一行） |
| `<details>` / `<summary>` | 折叠块（始终可用，不受 `enableHtml` 控制） |

块级标签需位于行首才按块解析；出现在段落中间时按内联降级规则处理。块内容会递归解析为 Markdown，因此块内可以使用标题、列表、代码块等语法。

## 样式安全子集

`<span style="...">` 仅识别以下 CSS 属性，其余静默忽略：

- `color`：`#RGB`、`#RRGGBB` 或常见颜色名（`red`、`blue` 等）
- `background-color`：同上
- `font-size`：`px`、`pt` 或纯数字（限制在 4–128px）

不支持 8 位 hex 颜色（CSS 与 Flutter 的通道顺序语义冲突）。

## 安全策略

- **标签白名单**：白名单之外的合法标签会被剥离，仅保留其内容（与聊天类渲染器一致）
- **URL scheme 校验**：`href` / `src` 仅允许 `http`、`https`、`mailto`、`tel` 与相对路径；`javascript:`、`data:`、`file:` 等一律拒绝——不安全链接剥离标签保留文字，不安全图片降级为 alt 文本
- **词法边界**：单个标签最长 512 字符，嵌套深度上限 16，防止病态输入
- **代码保护**：行内代码、代码块、数学公式中的 `<` 不会被解析

## 降级行为

- `a < b`、`2<3`、`<3` 等非法标签原样显示
- `\<b>` 反斜杠转义后原样显示
- 未闭合的标签自动闭合到文本 / 输入末尾——流式输出中途的 `<b>partial` 会即时渲染为加粗，收到 `</b>` 后自然收敛
- 游离的闭合标签（如无配对的 `</b>`）被静默忽略

## 已知限制

- HTML 实体（`&amp;` 等）暂不解码
- `kbd` / `sub` / `sup` / `img` 以 WidgetSpan 渲染，在选择模式下不可选中（与行内图片同类限制）
- 嵌套的文字装饰（如 `<u><s>x</s></u>`）内层覆盖外层，不叠加
- 块级 `align` 对齐的是整个内容块，不改变段落内每行文字的对齐
- 编辑器所见即所得模式（WYSIWYG）暂未接入 `enableHtml`，仅预览模式生效

## 主题定制

新增的样式字段（均可空，`light()` / `dark()` 已填充默认值）：

```dart
MarkdownStyleSheet.light().copyWith(
  underlineStyle: ...,   // <u>
  highlightStyle: ...,   // <mark>
  kbdStyle: ...,         // <kbd>
  subscriptStyle: ...,   // <sub>
  superscriptStyle: ..., // <sup>
)
```
