# Contributing to Flutter Smooth Markdown

First off, thank you for considering contributing to Flutter Smooth Markdown! It's people like you that make this package better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** - Include code snippets, screenshots, or sample markdown
- **Describe the behavior you observed** and what you expected to see
- **Include your environment details** - Flutter version, Dart version, platform (iOS/Android/Web/Desktop)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful** to most users
- **List some examples** of how it would be used

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow the coding style** - We use `flutter_lints` for code quality
3. **Write tests** - Ensure your code is well-tested
4. **Update documentation** - Keep the README and docs up to date
5. **Write good commit messages** - Follow conventional commits format

#### Pull Request Process

1. Update the README.md with details of changes if applicable
2. Update the CHANGELOG.md under the "Unreleased" section
3. Ensure all tests pass: `flutter test`
4. Ensure code is formatted: `dart format .`
5. Ensure no analyzer warnings: `flutter analyze`
6. Request review from maintainers

## Development Setup

### Prerequisites

- Flutter SDK 3.38.0 or later with Dart SDK 3.10.0 or later
- For native tests and builds, install Rust and Cargo with the target for your platform. See the [native build instructions](https://github.com/JackCaow/flutter-smooth-markdown/blob/main/docs/rust-core.md).

### Getting Started

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/flutter-smooth-markdown.git
cd flutter-smooth-markdown

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run the example app
cd example
flutter pub get
flutter run
```

### Project Structure

```
lib/
├── src/
│   ├── config/          # Configuration and style sheets
│   ├── parser/          # Markdown parser implementation
│   │   ├── ast/         # AST node definitions
│   │   ├── block_parser.dart
│   │   └── inline_parser.dart
│   └── renderer/        # Widget renderer implementation
│       └── builders/    # Widget builders for each markdown element
└── widgets/             # Public-facing widgets

test/
├── parser/              # Parser tests
└── renderer/            # Renderer and widget tests

example/                 # Example application
docs/                    # Documentation
```

## Coding Guidelines

### Dart Style Guide

- Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter_lints` for linting (already configured)
- Format code with `dart format`
- Maximum line length: 80 characters (recommended), 120 characters (hard limit)

### Documentation

- Add dartdoc comments for all public APIs
- Include examples in doc comments when helpful
- Keep README.md up to date

### Testing

- Write unit tests for all new features
- Maintain or improve code coverage
- Widget tests for UI components
- Integration tests for complex scenarios

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): subject

body

footer
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(parser): add support for definition lists

Add parser support for definition lists following the CommonMark spec extension.

Closes #123
```

```
fix(renderer): correct table alignment rendering

Table cells were not respecting alignment attributes. This fix ensures
that left, center, and right alignment are properly applied.
```

## Feature Development Workflow

### Adding a New Markdown Feature

1. **Add AST Node** - Define the node in `lib/src/parser/ast/markdown_node.dart`
2. **Update Parser** - Add parsing logic in `block_parser.dart` or `inline_parser.dart`
3. **Create Builder** - Implement widget builder in `lib/src/renderer/builders/`
4. **Register Builder** - Add to default registry in `markdown_renderer.dart`
5. **Write Tests** - Add comprehensive tests
6. **Update Docs** - Document the feature in README.md
7. **Add Example** - Create or update example demonstrating the feature

### Adding a New Theme

1. Add factory method to `MarkdownStyleSheet` in `lib/src/config/style_sheet.dart`
2. Define all style properties with appropriate colors and decorations
3. Add both light and dark variants
4. Update README.md theme section
5. Add example to the example app

## Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/parser/block_parser_test.dart

# Run tests in watch mode
flutter test --watch
```

### Writing Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

void main() {
  group('FeatureName', () {
    test('should do something', () {
      // Arrange
      final input = 'test input';

      // Act
      final result = parseFeature(input);

      // Assert
      expect(result, expectedOutput);
    });
  });
}
```

## Code Review Process

All submissions require review. We use GitHub pull requests for this purpose. The review process includes:

1. **Automated Checks** - CI must pass (tests, linting, formatting)
2. **Code Review** - At least one maintainer must approve
3. **Testing** - Reviewers may test the changes locally
4. **Documentation Review** - Ensure docs are updated

## Release Process

Maintainers handle releases following semantic versioning:

- **Major version (X.0.0)** - Breaking changes
- **Minor version (0.X.0)** - New features, backwards compatible
- **Patch version (0.0.X)** - Bug fixes

## Questions?

- Open an issue with the `question` label
- Start a discussion in GitHub Discussions
- Check existing documentation and issues first

## Recognition

Contributors will be recognized in:
- GitHub contributors page
- Release notes for significant contributions
- Special thanks in README for major features

Thank you for contributing! 🎉
