# CLAUDE.md - Tmux Workspace Documentation

**Complete documentation of the 5-window Python development tmux workspace design and implementation.**

## 🎯 Project Context

**Purpose**: Personal reusable Python development layout optimized for flake8-performance-patterns plugin development
**User**: Personal workflow, not universal - optimized for AI CLI usage, vim, and specific tool preferences
**Focus**: Educational Python linting plugin with book references from "High Performance Python" and "Effective Python"

## 🏗️ Design Decisions & Rationale

### **Window Count: 5 Windows**
- **Window 1**: Main development
- **Window 2**: Testing & validation
- **Window 3**: AI research & documentation
- **Window 4**: Git & project management
- **Window 5**: Debugging & AST analysis

**Rationale**: User's workflow is Code → Test → AI → Code → Test → Git → Repeat. Each window serves a distinct purpose in this cycle.

### **Window Numbering**: tmux windows start from 1, panes from 0 (user preference)

## 📋 Detailed Window Specifications

### **Window 1: "dev" (Main Development)**

#### **Layout**: Horizontal split with 3 panes
```
┌─────────────────────────────────────┐ 70%
│   VIM (main development)            │
├─────────────────┬───────────────────┤ 30%
│   Terminal      │   ptpython REPL   │ 15% each
│   (clean)       │   (AST tools)     │
└─────────────────┴───────────────────┘
```

#### **Design Decisions**:
- **70% vim**: More space needed for coding
- **ptpython preferred**: Fallback to python if not available
- **Clean terminal**: No startup messages, ready for fzf/pytest/commands
- **REPL pre-imports**: AST debugging tools auto-loaded
- **Default focus**: VIM pane for immediate coding

#### **Future Enhancement**: Layout switching between horizontal (A) and vertical (B) layouts
- **Layout A**: Current horizontal (good for portrait/most monitors)
- **Layout B**: Vertical split (good for landscape/wide monitors)
- **Implementation**: `Ctrl-b + L` toggle (deferred - needs careful testing)

#### **Startup Behavior**:
- **Pane 0**: `vim src/flake8_performance_patterns/__init__.py`
- **Pane 1**: Clean terminal with helpful comment
- **Pane 2**: ptpython with AST tools: `show_ast()`, `parse_file()`, `find_nodes()`

### **Window 2: "test" (Testing & Validation)**

#### **Layout**: Top/bottom split (60/40)
```
┌─────────────────────────────────────┐ 60%
│   Test Files (vim in tests/)        │
├─────────────────────────────────────┤ 40%
│   Test Output + Coverage            │
└─────────────────────────────────────┘
```

#### **Design Decisions**:
- **Top/bottom preferred**: Better for widescreen monitors, code needs horizontal space
- **60/40 ratio**: More space for test editing than output reading
- **Coverage reports included**: Worth including for plugin development
- **Most recent test file**: Auto-open latest modified test file

#### **User Workflow**: Write test → write code → test → enhance test → refactor

#### **Startup Behavior**:
- **Pane 0**: `cd tests && vim $(ls -t test_*.py | head -1)`
- **Pane 1**: Test commands reference + focus on pass/fail, error messages, coverage %

### **Window 3: "ai" (AI Research & Documentation)**

#### **Layout**: Top + bottom split (50/25/25)
```
┌─────────────────────────────────────┐ 50%
│   AI CLI                            │
├─────────────────┬───────────────────┤ 50%
│   Documentation │   Terminal        │ 25% each
│   (vim README)  │   (clean)         │
└─────────────────┴───────────────────┘
```

#### **Design Decisions**:
- **AI on top**: More space for AI interactions
- **Ask each time**: claude vs gemini choice per session
- **README.md default**: Most frequently edited documentation
- **Extra terminal**: Flexibility for tasks while AI thinks

#### **Enhanced Integration**:
- **Auto-copy on switch**: `Ctrl-b 3` copies last stdout to clipboard (silent)
- **No display messages**: Clean workflow without popup distractions
- **AI context awareness**: AI has directory access, can run git/commands

#### **Startup Behavior**:
- **Pane 0**: AI choice prompt, clipboard ready notification
- **Pane 1**: `vim README.md`
- **Pane 2**: Clean terminal for additional tasks

### **Window 4: "git" (Git & Project Management)**

#### **Layout**: Side-by-side (75/25)
```
┌─────────────────────────────┬─────────┐
│   LazyGit (75%)             │ Project │
│   (auto-start immediately)  │ Tree    │
└─────────────────────────────┴─────────┘
```

#### **Design Decisions**:
- **75/25 ratio**: LazyGit needs visual space for diffs, staging, history
- **Auto-start LazyGit**: Immediate availability in status view
- **treez command**: User's custom alias for nice project tree
- **Simple & clean**: Just essentials, AI handles complex git analysis

#### **Startup Behavior**:
- **Pane 0**: `lazygit` (auto-start)
- **Pane 1**: `treez` (with fallbacks to eza/find)

### **Window 5: "debug" (Debugging & AST Analysis)**

#### **Layout**: 4-pane hybrid (60/40 top/bottom, 50/50 left/right)
```
┌─────────────────┬─────────────────┐ 60%
│   Code Analysis │   AST Explorer  │
│   (empty vim)   │   (Python REPL  │
│                 │   + AST tools)  │
├─────────────────┼─────────────────┤ 40%
│   Debugger      │   Plugin Test   │
│   (ptpython +   │   (clean        │
│   debugging)    │    terminal)    │
└─────────────────┴─────────────────┘
```

#### **Design Decisions**:
- **4 panes**: Hybrid approach combining interactive debugging (B) + AST exploration (C)
- **60/40 top/bottom**: More space for analysis than debugging
- **50/50 left/right**: Equal space for code vs output
- **Empty vim default**: Ready to open any problematic file
- **Default focus**: Code analysis pane (top-left)

#### **User Workflow**: Write detection code → test on examples → debug failures → fix

#### **Startup Behavior**:
- **Pane 0**: Empty vim (default focus)
- **Pane 1**: ptpython with debugging tools + plugin imports
- **Pane 2**: Python REPL with comprehensive AST tools
- **Pane 3**: Clean terminal for `flake8` testing

#### **Deferred Features**:
- **Auto-AST integration**: Open file in vim → auto-show AST (too complex for now)
- **Manual shortcuts**: Copy file path between panes (not needed yet)

## 🔧 Technical Implementation Details

### **Script Arguments**:
```bash
./setup_workspace.sh [project_path] [session_name]
# Defaults: ./flake8-performance-patterns flake8-perf
```

### **Tool Detection & Fallbacks**:
- **ptpython** → python3 (throughout)
- **treez** → eza → find (project structure)
- **lazygit** (required, no fallback)

### **Key Bindings Enhanced**:
- **Ctrl-b 3**: Auto-copy last stdout + switch to AI window
- **Future: Ctrl-b L**: Layout toggle for Window 1 (not implemented)

### **Session Management**:
- **Conflict detection**: Auto-attach if session exists
- **Clean startup**: Clear instructions and status
- **Default focus**: Window 1, Pane 0 (vim)

## 🧪 Testing & Validation

### **Prerequisites**:
```bash
# Required tools
- tmux
- vim
- lazygit
- python3

# Optional (with fallbacks)
- ptpython
- treez (user's custom alias)
- eza
```

### **Project Structure Expected**:
```
flake8-performance-patterns/
├── src/flake8_performance_patterns/
│   └── __init__.py
├── tests/
│   └── test_*.py files
├── examples/
├── docs/
└── README.md
```

### **Test Workflow**:
1. **Create basic structure** → Run script → Verify all windows
2. **Test navigation** → Ctrl-b [1-5] between windows
3. **Test auto-copy** → Generate output → Ctrl-b 3 → Check clipboard
4. **Test tools** → ptpython availability, LazyGit startup, treez command

## 🐛 Common Issues & Debugging

### **LazyGit Won't Start**:
- **Check installation**: `which lazygit`
- **Path issues**: Add lazygit to PATH
- **Alternative**: Manual start with `tmux send-keys -t git.0 "lazygit" Enter`

### **ptpython Not Found**:
- **Expected behavior**: Falls back to python3
- **Install ptpython**: `pip install ptpython`
- **Verify fallback**: Should show "AST tools loaded!" in regular Python

### **treez Command Failed**:
- **Check alias**: `which treez`
- **Fallback chain**: treez → eza → find
- **Manual fix**: Replace treez with `eza --tree` or custom command

### **Auto-copy Not Working**:
- **Check wl-copy**: `which wl-copy` (Wayland clipboard)
- **X11 alternative**: Replace with `xclip -selection clipboard`
- **Test manually**: Run the awk command manually

### **Session Creation Fails**:
- **tmux version**: Ensure modern tmux (2.6+)
- **Directory permissions**: Check project directory access
- **Manual debugging**: Run commands step by step

### **Pane Sizing Issues**:
- **Terminal size**: Very small terminals may cause layout problems
- **Manual resize**: `tmux resize-pane -t window.pane -x 50%`
- **Layout reset**: `tmux select-layout -t window even-horizontal`

## 🚀 Future Enhancements

### **Immediate (Next Session)**:
- **Layout switching**: Window 1 horizontal ↔ vertical toggle
- **Tool availability check**: Better detection and user feedback
- **Error handling**: Graceful degradation for missing tools

### **Medium Term**:
- **Project detection**: Auto-adjust for different Python project types
- **Template variants**: Data science, web dev, CLI tool variants
- **Integration shortcuts**: Quick file/context sharing between panes

### **Advanced Ideas**:
- **AI integration**: Smart context sharing between windows
- **Session templates**: Multiple workspace types
- **Performance monitoring**: Plugin development metrics

## 📝 User Workflow Mapping

### **Typical Development Session**:
1. **Start**: `./setup_workspace.sh` → Window 1 (dev) with vim ready
2. **Code**: Edit main plugin files in Window 1
3. **Test**: Switch to Window 2 → run pytest → see results
4. **Debug**: Issues found → Window 5 → analyze AST → debug logic
5. **AI Help**: Window 3 → ask claude/gemini (auto-copy errors)
6. **Implement**: Back to Window 1 → apply suggestions
7. **Verify**: Window 2 → run tests again
8. **Commit**: Window 4 → LazyGit staging → commit → push
9. **Repeat**: Continuous development cycle

### **Window Usage Patterns**:
- **Window 1**: 60% of time (main development)
- **Window 2**: 20% of time (testing)
- **Window 3**: 10% of time (AI assistance)
- **Window 4**: 5% of time (git operations)
- **Window 5**: 5% of time (deep debugging)

## 🎯 Success Metrics

### **Workflow Efficiency**:
- **Quick context switching**: ≤2 keystrokes between windows
- **Tool availability**: All required tools accessible in ≤1 command
- **Focus maintenance**: Minimal cognitive overhead for navigation

### **Development Experience**:
- **Immediate productivity**: Ready to code within 10 seconds of script run
- **Context preservation**: Work survives session detach/reattach
- **Tool integration**: Seamless AI assistance with auto-copy

## 📚 Implementation Notes

### **Code Style**:
- **Bash best practices**: Proper quoting, error handling
- **Fallback strategy**: Graceful degradation for missing tools
- **User feedback**: Clear status messages and instructions

### **Maintainability**:
- **Modular design**: Each window setup is independent
- **Clear documentation**: This file serves as complete reference
- **Version compatibility**: Works with modern tmux versions

---

**Last Updated**: Based on complete design session
**Status**: Implemented and ready for testing
**Next Steps**: User testing → feedback → refinement → layout switching feature
