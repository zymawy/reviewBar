# Contributing to ReviewBar

First off, thank you for considering contributing to ReviewBar! 🎉

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Style Guide](#style-guide)

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- Swift 5.9+

### Setup

```bash
# Fork and clone
git clone https://github.com/zymawy/reviewBar.git
cd reviewBar

# Build
swift build

# Run tests
swift test

# Run the app
swift run ReviewBar
```

## How to Contribute

### Reporting Bugs

1. Check existing [issues](https://github.com/zymawy/reviewBar/issues) first
2. Create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - macOS version and app version

### Suggesting Features

Open an issue with the `enhancement` label describing:
- The problem you're trying to solve
- Your proposed solution
- Alternatives you've considered

### Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`swift test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Workflow

### Project Structure

```
Sources/
├── ReviewBar/          # Main macOS app
├── ReviewBarCore/      # Shared library (models, services)
└── ReviewBarCLI/       # Command-line interface
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `ReviewStore` | `ReviewBar/` | Central state management |
| `LLMProvider` | `ReviewBarCore/Agents/` | AI provider protocol |
| `GitHubProvider` | `ReviewBarCore/Providers/` | GitHub API integration |
| `DashboardView` | `ReviewBar/Views/` | Main UI |

### Running Tests

```bash
# All tests
swift test

# Specific test
swift test --filter DiffParserTests
```

## Pull Request Process

1. **Update documentation** — Include README updates if adding features
2. **Add tests** — Cover new code with unit tests
3. **Follow style guide** — See below
4. **One feature per PR** — Keep PRs focused
5. **Describe changes** — Explain what and why in the PR description

### PR Checklist

- [ ] Code compiles without warnings
- [ ] Tests pass (`swift test`)
- [ ] Documentation updated
- [ ] Commits have clear messages
- [ ] Branch is up to date with `main`

## Style Guide

### Swift

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use `// MARK: -` to organize code sections
- Prefer `let` over `var` when possible
- Use meaningful variable names

### Commits

Use conventional commit messages:

```
feat: Add Slack notification support
fix: Handle empty diff gracefully
docs: Update installation instructions
refactor: Extract LLM logic to separate module
```

### Code Organization

```swift
// MARK: - Properties

// MARK: - Init

// MARK: - Public Methods

// MARK: - Private Methods
```

---

Thank you for contributing! 🚀
