# 🤝 Contributing to AdaptiveQuantGrid

Thank you for your interest in contributing to AQG! This document provides guidelines for contributing to the project.

---

## 🐛 Reporting Bugs

Before creating a bug report, please check existing issues to see if the problem has already been reported.

### When submitting a bug report, include:

1. **Clear title and description**
2. **Steps to reproduce** the behavior
3. **Expected behavior** vs **actual behavior**
4. **Screenshots** if applicable
5. **Environment details:**
   - MT5 build version
   - Symbol and timeframe
   - EA parameters used
   - Broker (optional, for context)
6. **Logs** from the Experts tab (set `InpLogLevel = 3` for DEBUG)

### Example Bug Report

```
Title: GridCalculator places orders inside freeze level on GBPUSD

Steps to Reproduce:
1. Attach EA to GBPUSD H1
2. Set InpMinStepPoints = 50
3. Wait for initial orders placement

Expected: Orders placed outside freeze level
Actual: Buy Limit placed inside freeze zone, rejected by broker

Environment:
- MT5 Build: 3950
- Symbol: GBPUSD
- Broker: IC Markets
- InpLogLevel: 3

Logs:
[GBPUSD:H1] 🔴 ERROR: Buy Limit failed | Code: 10016
```

---

## 💡 Suggesting Features

Feature suggestions are welcome! Please provide:

1. **Use case** — What problem does this solve?
2. **Proposed solution** — How should it work?
3. **Alternatives considered** — Any other approaches?
4. **Additional context** — Screenshots, mockups, examples

### Example Feature Request

```
Title: Add time-based trading filter

Use Case:
Many users want to restrict trading to specific hours (e.g., London session only)
to avoid low-volatility periods.

Proposed Solution:
Add input parameters:
- InpStartHour = 8  (London open)
- InpEndHour = 17   (London close)
EA skips order placement outside this window.

Alternatives:
- Could use external filters via DLL, but built-in is simpler
```

---

## 🔧 Pull Requests

### Before submitting

1. **Fork** the repository
2. **Create a feature branch** (`feature/my-new-feature`)
3. **Make your changes**
4. **Test thoroughly** on a demo account
5. **Update documentation** if needed
6. **Commit** with clear messages

### Commit Message Format

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat` — New feature
- `fix` — Bug fix
- `docs` — Documentation changes
- `style` — Code style changes (formatting, no logic change)
- `refactor` — Code refactoring (no behavior change)
- `perf` — Performance improvements
- `test` — Adding or modifying tests
- `chore` — Maintenance tasks

**Examples:**
```
fix: GridCalculator syncs step from positions, not orders

feat: Add time-based trading filter

docs: Update MANUAL.md with new parameters

refactor: Extract price validation to helper method
```

### Code Style

- Follow existing MQL5 coding conventions
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused (< 50 lines ideal)
- Use `#include <AQG/...>` for module imports

### Testing Checklist

Before submitting a PR:
- [ ] Code compiles without warnings in MetaEditor
- [ ] Tested on demo account
- [ ] No errors in journal at `InpLogLevel = 2`
- [ ] State recovery works after restart
- [ ] Emergency stop triggers correctly
- [ ] No memory leaks (handles closed properly)

---

## 📐 Architecture Guidelines

When adding new features, follow these principles:

1. **Modularity** — New features should be self-contained modules
2. **Non-breaking** — Don't change existing behavior without good reason
3. **Configurable** — New features should have input parameters for enable/disable
4. **Documented** — Update MANUAL.md and docs/ARCHITECTURE.md
5. **Safe** — Include risk checks and error handling

### Adding a New Module

```mql5
// AQG_NewModule.mqh
#property version   "1.00"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>

class CAQGNewModule
{
private:
   string m_symbol;
   int    m_magic;
   bool   m_isInitialized;

public:
   CAQGNewModule();
   ~CAQGNewModule();

   bool Init(string symbol, int magic);
   void Deinit();
   void Update(); // Main logic, call from OnTick
};
```

---

## 🚫 What We Don't Accept

- Code that breaks existing functionality without notice
- Hardcoded API keys, passwords, or personal data
- Unoptimized code that significantly slows down OnTick
- Features that require external DLLs (security risk)
- Code that doesn't compile in MetaEditor

---

## 📞 Contact

For questions or discussions:
- Open a [Discussion](https://github.com/yourusername/AdaptiveQuantGrid/discussions)
- Comment on relevant issues

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🎉
