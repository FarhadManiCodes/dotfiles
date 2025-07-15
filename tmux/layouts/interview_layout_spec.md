# Interview Layout Technical Specification

**Document Version**: 1.0  
**Date**: July 2025  
**Purpose**: Complete technical specification for `interview_layout.sh` tmux session

## Overview

The interview layout is a specialized 4-window tmux session designed for technical interviews in data engineering and data science roles. It provides integrated tools for coding, data analysis, communication, and feature engineering while maintaining professional appearance and workflow efficiency.

## Architecture

### Session Structure
- **Session Name**: `interview-$(basename "$PWD")`
- **Total Windows**: 4
- **Working Directory**: Current directory (`$PWD`)
- **Integration**: Shared `./interview_data/` directory across all tools

## Window Specifications

### Window 1: "workspace" - Primary Coding

**Purpose**: Main coding environment for algorithm implementation and solution development

#### Layout (4 panes)
```
┌─────────────────────────────────┬──────────────┐
│                                 │              │
│         MAIN EDITOR             │   PYTHON     │
│      (vim + interview theme)    │    REPL      │
│                70% x 70%        │   30% x 70%  │
│                                 │              │
├─────────────────────────────────┼──────────────┤
│           TEST OUTPUT           │   QUICK      │ 
│        (pytest results)        │   NOTES      │
│          70% x 30%              │   30% x 30%  │
└─────────────────────────────────┴──────────────┘
```

#### Pane 0: Main Editor (70% width, 70% height)
- **Tool**: Vim with interview-optimized configuration
- **Theme**: Clean, professional theme suitable for screen sharing
- **Font**: Large, readable font size (TBD during implementation)
- **Configuration**: 
  - `set number relativenumber`
  - Clean colorscheme
  - No distracting plugins
  - Auto-save enabled

#### Pane 1: Python REPL (30% width, 70% height)
- **Tool**: ptpython
- **Pre-loaded imports**:
  ```python
  import sys, os, math, heapq, bisect
  from collections import defaultdict, deque, Counter
  from typing import List, Dict, Optional, Tuple, Set
  import pandas as pd, numpy as np
  ```
- **Startup message**: "🐍 Interview environment ready!"

#### Pane 2: Test Output (70% width, 30% height)
- **Tool**: pytest with verbose output
- **Manual execution**: User triggers tests manually
- **Display**: Shows test results, errors, and output

#### Pane 3: Quick Notes (30% width, 30% height)
- **Format**: Plain text
- **Template**:
  ```
  📝 Quick Notes:
  Problem: 
  Approach: 
  Time Complexity: 
  Space Complexity: 
  Edge Cases:
  ```

### Window 2: "data" - Data Engineering Playground

**Purpose**: Data analysis, exploration, and manipulation (borrowed from existing analysis_layout.sh)

#### Layout (4 panes)
```
┌─────────────────────────────────┬─────────────┐
│                                 │             │
│        FDATA-PREVIEW            │   DUCKDB    │
│     (enhanced data browser)     │ (auto-loaded│
│          60% x 95%              │   + watch)  │
│                                 │  40% x 50%  │
├─────────────────────────────────┼─────────────┤
│         TINY SHELL              │ PTIPYTHON   │
│          60% x 5%               │ (pandas/np) │
│                                 │  40% x 50%  │
└─────────────────────────────────┴─────────────┘
```

#### Pane 0: fdata-preview (60% width, 95% height)
- **Tool**: Existing fdata-preview from `$DOTFILES/zsh/specials/fzf_data.sh`
- **Purpose**: Sophisticated data browser with file analysis
- **Integration**: Shows files from `./interview_data/` directory

#### Pane 1: Tiny Shell (60% width, 5% height)
- **Purpose**: Quick commands without leaving data context
- **Includes**: Small profiler selector
- **Commands**:
  ```bash
  fdata-profile <file>           # Your existing profiler
  comprehensive-profile          # Switch to comprehensive layout
  ```

#### Pane 2: DuckDB (40% width, 50% height)
- **Tool**: DuckDB with auto-loaded data
- **Setup Script**: `$DOTFILES/zsh/specials/load_data_duckdb.sh`
- **Features**:
  - duck-watch integration for result monitoring
  - Pre-configured CSV output mode
  - Auto-loads sample datasets and interview data

#### Pane 3: ptipython (40% width, 50% height)
- **Tool**: ptipython (enhanced ptpython)
- **Pre-loaded imports**:
  ```python
  import pandas as pd, numpy as np
  from pathlib import Path
  import json
  ```
- **Purpose**: Data manipulation and analysis

### Window 3: "analysis" - Feature Engineering & Statistics

**Purpose**: Feature engineering workspace and statistical analysis tools

#### Layout (2 panes)
```
┌─────────────────────────────────────────────────┐
│                                                 │
│           FEATURE ENGINEERING                   │
│          (pandas + transforms)                  │
│                 100% x 50%                      │
├─────────────────────────────────────────────────┤
│                                                 │
│            STATS ANALYSIS                       │
│          (scipy.stats + tests)                  │
│                 100% x 50%                      │
└─────────────────────────────────────────────────┘
```

#### Pane 0: Feature Engineering (100% width, 50% height)
- **Tool**: ptpython with feature engineering focus
- **Pre-loaded imports**:
  ```python
  import pandas as pd
  import numpy as np
  from sklearn.preprocessing import StandardScaler, LabelEncoder, OneHotEncoder
  from sklearn.feature_selection import SelectKBest, chi2, f_classif
  ```

- **Pre-loaded helper functions**:
  ```python
  def create_datetime_features(df, date_col):
      """Extract year, month, day, dayofweek from datetime column"""
      df[f'{date_col}_year'] = df[date_col].dt.year
      df[f'{date_col}_month'] = df[date_col].dt.month
      df[f'{date_col}_day'] = df[date_col].dt.day
      df[f'{date_col}_dayofweek'] = df[date_col].dt.dayofweek
      return df

  def create_interaction_features(df, col1, col2):
      """Create interaction feature between two columns"""
      df[f'{col1}_{col2}_interaction'] = df[col1] * df[col2]
      return df

  def quick_binning(df, col, bins=5):
      """Create binned version of continuous variable"""
      df[f'{col}_binned'] = pd.cut(df[col], bins=bins, labels=False)
      return df
  ```

#### Pane 1: Stats Analysis (100% width, 50% height)
- **Tool**: ptpython with statistical analysis focus
- **Pre-loaded imports**:
  ```python
  from scipy import stats
  import statsmodels.api as sm
  import numpy as np
  ```

- **Pre-loaded helper functions**:
  ```python
  def quick_ttest(group1, group2):
      """Perform independent t-test between two groups"""
      statistic, p_value = stats.ttest_ind(group1, group2)
      print(f"T-test: statistic={statistic:.3f}, p-value={p_value:.3f}")
      return statistic, p_value

  def quick_correlation(df, col1, col2):
      """Calculate Pearson correlation between two columns"""
      corr, p_value = stats.pearsonr(df[col1], df[col2])
      print(f"Correlation: {corr:.3f}, p-value={p_value:.3f}")
      return corr, p_value

  def quick_anova(df, category_col, numeric_col):
      """Perform one-way ANOVA"""
      groups = [group[numeric_col].values for name, group in df.groupby(category_col)]
      f_stat, p_value = stats.f_oneway(*groups)
      print(f"ANOVA: F={f_stat:.3f}, p-value={p_value:.3f}")
      return f_stat, p_value
  ```

### Window 4: "comm" - Communication Hub

**Purpose**: Handle file transfers, email monitoring, and communication with interviewers

#### Layout (4 panes)
```
┌─────────────────────┬─────────────────────┐
│       EMAIL         │     FILE DOWNLOAD   │
│   (himalaya)        │   (smart-download)  │
│      50% x 50%      │      50% x 50%      │
├─────────────────────┼─────────────────────┤
│    FILE MONITOR     │      QUICK SHARE    │
│  (multi-platform)   │   (copy + zip)      │
│      50% x 50%      │      50% x 50%      │
└─────────────────────┴─────────────────────┘
```

#### Pane 0: Email (50% width, 50% height)
- **Tool**: himalaya (fast, simple email client)
- **Features**:
  - Domain filtering for interview company
  - Auto-download of CSV/data file attachments
  - Safe download system with validation
- **Configuration**: Tokens stored in config files
- **Supported formats**: csv, json, xlsx, zip, txt, sql, py
- **Size limit**: 100MB per file

#### Pane 1: File Download (50% width, 50% height)
- **Tools**: wget, curl, gh (if available)
- **Features**:
  - Smart URL detection and appropriate tool selection
  - Auto-extraction with user prompt
  - Same size limits as email (100MB)
- **Output directory**: `./interview_data/` (shared with other windows)

#### Pane 2: File Monitor (50% width, 50% height)
- **Purpose**: Monitor chat platforms for file attachments and URLs
- **Supported platforms**: Slack, Teams, Discord (manual setup per interview)
- **Features**:
  - Configurable scan frequency (default 30 seconds)
  - Single channel monitoring per platform
  - Detects both attachments and file URLs
- **Authentication**: Tokens stored in config files

#### Pane 3: Quick Share (50% width, 50% height)
- **Purpose**: Share solutions via copy/paste or email
- **Features**:
  - Copy files to clipboard
  - Create email-ready zip files
  - Show recently modified files (last 30 minutes)
- **Focus**: Practical interview sharing (copy/paste + email attachment)

## Integration Features

### Safe Download System
All file downloads use a secure process:

1. **File Type Validation**: Real MIME type checking, not just extensions
2. **Size Limits**: 100MB maximum file size
3. **Domain Whitelisting**: Email filtering by company domain
4. **Quarantine Process**: 
   - Download to `./interview_downloads_quarantine/`
   - Validate file type and size
   - Move to `./interview_data/` if safe
   - Auto-integration with data window

### Cross-Window Communication
- **Shared Directory**: `./interview_data/` used by all windows
- **Auto-notifications**: tmux messages when files downloaded
- **Data Window Integration**: New files automatically appear in Window 2
- **Auto-preview**: CSV files auto-load into DuckDB

### File Flow Integration
```
Email Attachment → Safe Download → ./interview_data/ → Data Window Refresh → DuckDB Auto-load
Chat File Link → Smart Download → ./interview_data/ → Data Window Refresh → Auto-preview
Manual Download → ./interview_data/ → Data Window Integration
```

## Technical Requirements

### Dependencies
- **Core Tools**: tmux, vim, python3
- **Email**: himalaya
- **Python Packages**: pandas, numpy, scikit-learn, scipy, statsmodels
- **Data Tools**: DuckDB, ptpython
- **File Tools**: fd, fzf, bat (optional), qsv (optional)
- **Download Tools**: wget, curl, gh (optional)
- **Clipboard**: wl-copy (Wayland) or xclip (X11)

### File Structure
```
./
├── interview_data/              # Shared data directory
├── interview_downloads_quarantine/  # Temporary quarantine
└── interview_20250706_1435.zip # Email-ready solution archives
```

### Configuration Files
- `~/.config/himalaya/config.toml` - Email configuration
- `~/.config/interview/chat_config` - Chat platform tokens
- `~/.config/interview/responses.txt` - Quick response templates

## Safety and Security

### File Download Security
- **Allowed Extensions**: csv, json, xlsx, zip, txt, sql, py
- **MIME Type Validation**: Actual file type verification
- **Size Restrictions**: 100MB maximum
- **Domain Filtering**: Only trusted company domains for email
- **Quarantine System**: All files validated before integration

### Professional Considerations
- **Clean Interface**: Large fonts, professional themes for screen sharing
- **No Sensitive Data**: No personal aliases or configuration exposed
- **Minimal Distractions**: Clean, focused interface
- **Fast Response Times**: Quick file handling and communication

## Implementation Notes

### Layout Script Location
- **Primary**: `$HOME/.config/tmux/layouts/interview_layout.sh`
- **Alternative**: `$DOTFILES/tmux/layouts/interview_layout.sh`

### Session Management
- **Creation**: Check for existing session before creating
- **Attachment**: Handle both nested tmux and direct attachment
- **Environment**: Set `TMUX_SMART_START=1` to prevent auto-attachment conflicts

### Window Selection
- **Default Start**: Window 1 (workspace) - pane 0 (main editor)
- **Flexibility**: All windows self-contained for any starting point

### Error Handling
- **Missing Tools**: Graceful degradation when optional tools unavailable
- **Failed Downloads**: Clear error messages and fallback options
- **Configuration Issues**: Helpful setup guidance

## Usage Examples

### Typical Interview Flow
1. **Pre-interview**: Run `interview-chat-setup company.com slack`
2. **Start Session**: `interview_layout.sh`
3. **Receive Dataset**: Auto-downloaded to `./interview_data/`, appears in Window 2
4. **Code Solution**: Window 1 for implementation, Window 2 for data exploration
5. **Feature Engineering**: Window 3 for advanced data transformations
6. **Share Solution**: Window 4 to copy/paste or email solution

### Command Examples
```bash
# Setup for specific company
interview-chat-setup google.com slack

# Start interview session
~/.config/tmux/layouts/interview_layout.sh

# Within session - quick actions
cp solution.py          # Copy to clipboard (Window 4)
fdata-profile data.csv  # Profile data file (Window 2)
scan                    # Manual file scan (Window 4)
```

## Future Enhancements

### Planned Additions
- **ML Model Playground**: Dedicated machine learning workspace (design TBD)
- **Performance Analysis**: Query timing and optimization tools
- **Visualization Templates**: Quick matplotlib/seaborn templates for Jupyter

### Configuration Improvements
- **Company Profiles**: Pre-configured setups for major tech companies
- **Template Customization**: User-customizable helper functions
- **Theme Options**: Multiple professional themes for different preferences

---

**Document Status**: Complete technical specification ready for implementation  
**Next Steps**: Implement `interview_layout.sh` based on this specification