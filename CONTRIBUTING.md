# Contributing to PlanReview

Thank you for your interest in contributing! This document provides guidelines for contributing to PlanReview.

## Development Setup

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15+ or Swift 5.9+ toolchain
- Git

### Building from Source

```bash
# Clone the repository
git clone https://github.com/zeigarnick/PlanReview.git
cd PlanReview

# Build debug version
swift build

# Run the debug build
.build/debug/PlanReview

# Build release version
swift build -c release
```

### Running Tests

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose
```

### Installing Locally

```bash
# Build and install to /Applications
./build.sh

# Link CLI to PATH
sudo ln -sf "$(pwd)/planreview-cli" /usr/local/bin/planreview
```

## Project Structure

```
PlanReview/
├── Sources/                    # Swift source files
│   ├── PlanReviewApp.swift    # App entry point, window management
│   ├── MainWindowView.swift   # Main window layout with toolbar
│   ├── ContentView.swift      # Document content view
│   ├── TabManager.swift       # Multi-tab document management
│   ├── TabBarView.swift       # Tab bar UI
│   ├── ReviewDocument.swift   # Document model and persistence
│   ├── CommentsSidebar.swift  # Comments sidebar
│   └── Markdown/              # Markdown rendering
│       ├── MarkdownWKWebView.swift  # WKWebView-based renderer (primary)
│       ├── MarkdownRenderer.swift
│       ├── MarkdownTextView.swift
│       ├── MarkdownTheme.swift
│       └── CommentHighlighter.swift
├── Tests/                      # Unit tests
├── PlanReview.app/            # App bundle template
├── planreview-cli             # CLI wrapper script
├── build.sh                   # Build and install script
└── Package.swift              # SPM configuration (swift-markdown + Ink)
```

## Making Changes

### Workflow

1. **Fork the repository** and create a feature branch
2. **Make your changes** with clear, focused commits
3. **Add tests** for new functionality
4. **Ensure tests pass**: `swift test`
5. **Submit a Pull Request** with a clear description

### Commit Messages

Write clear commit messages:
- Use present tense ("Add feature" not "Added feature")
- First line: brief summary (50 chars or less)
- Body: explain what and why (if needed)

Example:
```
Add keyboard shortcut for quick approve

Cmd+Return now triggers approve action, matching common
editor patterns. This speeds up the review workflow for
keyboard-focused users.
```

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI idioms for UI code
- Keep functions focused and testable
- Add documentation comments for public APIs

## Types of Contributions

### Bug Reports

Open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

### Feature Requests

Open an issue describing:
- The problem you're trying to solve
- Your proposed solution
- Alternative solutions you considered

### Documentation

Documentation improvements are always welcome:
- README clarifications
- Code comments
- Usage examples

## Questions?

Open an issue for any questions about contributing. We're happy to help!
