start_time=$(date +%s.%N)
  source "$DOTFILES/zsh/productivity/fzf_profile.sh" >/dev/null 2>&1
  local fzf_profile_time=$(echo "$(date +%s.%#!/usr/bin/env zsh
# =============================================================================
# Profile System Validation Script
# Location: $DOTFILES/zsh/specials/validate_profile_system.sh
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
test_start() {
  local test_name="$1"
  echo -e "\n${BLUE}🧪 Testing: $test_name${NC}"
  echo "----------------------------------------"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_pass() {
  local message="$1"
  echo -e "${GREEN}✅ PASS: $message${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
  local message="$1"
  echo -e "${RED}❌ FAIL: $message${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_warn() {
  local message="$1"
  echo -e "${YELLOW}⚠️  WARN: $message${NC}"
}

test_info() {
  local message="$1"
  echo -e "${CYAN}💡 INFO: $message${NC}"
}

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

validate_environment() {
  test_start "Environment Setup"
  
  # Check DOTFILES variable
  if [[ -n "$DOTFILES" && -d "$DOTFILES" ]]; then
    test_pass "DOTFILES variable set: $DOTFILES"
  else
    test_fail "DOTFILES variable not set or directory doesn't exist"
    return 1
  fi
  
  # Check required tools
  local tools=("fd" "fzf" "yq" "python3")
  for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      test_pass "$tool is available"
    else
      test_fail "$tool is not available (required)"
    fi
  done
  
  # Check optional tools
  local optional_tools=("bat" "qsv" "jq")
  for tool in "${optional_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      test_pass "$tool is available (optional)"
    else
      test_warn "$tool is not available (optional but recommended)"
    fi
  done
}

# =============================================================================
# FILE STRUCTURE VALIDATION
# =============================================================================

validate_file_structure() {
  test_start "File Structure"
  
  local fzf_data="$DOTFILES/zsh/specials/fzf_data.sh"
  local fzf_profile="$DOTFILES/zsh/productivity/fzf_profile.sh"
  
  # Check if files exist
  if [[ -f "$fzf_data" ]]; then
    test_pass "fzf_data.sh exists"
  else
    test_fail "fzf_data.sh not found at: $fzf_data"
  fi
  
  if [[ -f "$fzf_profile" ]]; then
    test_pass "fzf_profile.sh exists"
  else
    test_fail "fzf_profile.sh not found at: $fzf_profile"
  fi
  
  # Check if files are readable
  if [[ -r "$fzf_data" ]]; then
    test_pass "fzf_data.sh is readable"
  else
    test_fail "fzf_data.sh is not readable"
  fi
  
  if [[ -r "$fzf_profile" ]]; then
    test_pass "fzf_profile.sh is readable"
  else
    test_fail "fzf_profile.sh is not readable"
  fi
}

# =============================================================================
# SYNTAX VALIDATION
# =============================================================================

validate_syntax() {
  test_start "Syntax Validation"
  
  local fzf_data="$DOTFILES/zsh/specials/fzf_data.sh"
  local fzf_profile="$DOTFILES/zsh/productivity/fzf_profile.sh"
  
  # Test syntax by sourcing in subshell
  if (source "$fzf_data") >/dev/null 2>&1; then
    test_pass "fzf_data.sh syntax is valid"
  else
    test_fail "fzf_data.sh has syntax errors"
    echo "Debug with: zsh -n $fzf_data"
  fi
  
  if (source "$fzf_profile") >/dev/null 2>&1; then
    test_pass "fzf_profile.sh syntax is valid"
  else
    test_fail "fzf_profile.sh has syntax errors"
    echo "Debug with: zsh -n $fzf_profile"
  fi
}

# =============================================================================
# FUNCTION AVAILABILITY TESTS
# =============================================================================

validate_fzf_data_functions() {
  test_start "fzf_data.sh Function Availability"
  
  local fzf_data="$DOTFILES/zsh/specials/fzf_data.sh"
  
  # Source the file in current shell
  if source "$fzf_data" 2>/dev/null; then
    test_pass "fzf_data.sh sourced successfully"
    
    # Check Phase 1 functions
    local phase1_functions=("_analyze_data_file" "fdata-preview" "fdata-tools-status" "fdata-help")
    for func in "${phase1_functions[@]}"; do
      if type "$func" >/dev/null 2>&1; then
        test_pass "Function $func is available"
      else
        test_fail "Function $func is not available"
      fi
    done
    
    # Check that Phase 2/3 functions are NOT present
    local phase23_functions=("load-profiling-config" "fdata-profile" "discover_profiles")
    for func in "${phase23_functions[@]}"; do
      if type "$func" >/dev/null 2>&1; then
        test_fail "Function $func should not be in fzf_data.sh (moved to fzf_profile.sh)"
      else
        test_pass "Function $func correctly not in fzf_data.sh"
      fi
    done
    
  else
    test_fail "Failed to source fzf_data.sh"
  fi
}

validate_fzf_profile_functions() {
  test_start "fzf_profile.sh Function Availability"
  
  local fzf_profile="$DOTFILES/zsh/productivity/fzf_profile.sh"
  
  # Source the file in current shell
  if source "$fzf_profile" 2>/dev/null; then
    test_pass "fzf_profile.sh sourced successfully"
    
    # Check Phase 2 functions
    local phase2_functions=("load-profiling-config" "show-profiling-config" "test-profiling-config")
    for func in "${phase2_functions[@]}"; do
      if type "$func" >/dev/null 2>&1; then
        test_pass "Phase 2 function $func is available"
      else
        test_fail "Phase 2 function $func is not available"
      fi
    done
    
    # Check Phase 3 functions
    local phase3_functions=("fdata-profile" "discover_profiles" "get_compatible_profiles")
    for func in "${phase3_functions[@]}"; do
      if type "$func" >/dev/null 2>&1; then
        test_pass "Phase 3 function $func is available"
      else
        test_fail "Phase 3 function $func is not available"
      fi
    done
    
    # Check completion functions
    local completion_functions=("_fdata_profile_completion")
    for func in "${completion_functions[@]}"; do
      if type "$func" >/dev/null 2>&1; then
        test_pass "Completion function $func is available"
      else
        test_fail "Completion function $func is not available"
      fi
    done
    
    # Check that Phase 1 functions are NOT present
    local phase1_functions=("_analyze_data_file" "fdata-preview")
    for func in "${phase1_functions[@]}"; do
      if type "$func" >/dev/null 2>&1; then
        test_fail "Function $func should not be in fzf_profile.sh (belongs in fzf_data.sh)"
      else
        test_pass "Function $func correctly not in fzf_profile.sh"
      fi
    done
    
  else
    test_fail "Failed to source fzf_profile.sh"
  fi
}

# =============================================================================
# CONFIGURATION SYSTEM TESTS
# =============================================================================

validate_configuration_system() {
  test_start "Configuration System"
  
  # Source profile system
  source "$DOTFILES/zsh/productivity/fzf_profile.sh" 2>/dev/null || {
    test_fail "Cannot source fzf_profile.sh for configuration tests"
    return 1
  }
  
  # Test configuration loading
  test_info "Testing configuration loading..."
  
  # Capture output
  local config_output
  config_output=$(load-profiling-config 2>&1)
  local config_result=$?
  
  if [[ $config_result -eq 0 ]]; then
    test_pass "load-profiling-config executed successfully"
    
    # Check if arrays are populated
    if [[ ${#PROFILING_SETTINGS[@]} -gt 0 ]]; then
      test_pass "PROFILING_SETTINGS array populated (${#PROFILING_SETTINGS[@]} items)"
    else
      test_warn "PROFILING_SETTINGS array is empty"
    fi
    
    # Test profiling directory
    local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-}"
    if [[ -n "$profiling_dir" ]]; then
      test_pass "Profiling directory configured: $profiling_dir"
      if [[ -d "$profiling_dir" ]]; then
        test_pass "Profiling directory exists"
      else
        test_warn "Profiling directory doesn't exist: $profiling_dir"
      fi
    else
      test_warn "No profiling directory configured"
    fi
    
  else
    test_fail "load-profiling-config failed"
    echo "Output: $config_output"
  fi
}

# =============================================================================
# PROFILE DISCOVERY TESTS
# =============================================================================

validate_profile_discovery() {
  test_start "Profile Discovery"
  
  # Source profile system
  source "$DOTFILES/zsh/productivity/fzf_profile.sh" 2>/dev/null || {
    test_fail "Cannot source fzf_profile.sh for discovery tests"
    return 1
  }
  
  # Load configuration first
  load-profiling-config >/dev/null 2>&1
  
  # Test profile discovery
  test_info "Testing profile discovery..."
  
  local discovery_output
  discovery_output=$(discover_profiles 2>&1)
  local discovery_result=$?
  
  if [[ $discovery_result -eq 0 ]]; then
    test_pass "discover_profiles executed successfully"
    
    # Check if profiles were discovered
    if [[ ${#DISCOVERED_PROFILES[@]} -gt 0 ]]; then
      test_pass "Profiles discovered: ${#DISCOVERED_PROFILES[@]} found"
      
      # List discovered profiles
      test_info "Discovered profiles:"
      for profile in "${(@k)DISCOVERED_PROFILES}"; do
        echo "    • $profile"
      done
      
    else
      test_warn "No profiles discovered (expected if no profiling directory exists)"
    fi
    
  else
    test_warn "discover_profiles failed (expected if no profiling directory)"
    test_info "Discovery output: $discovery_output"
  fi
}

# =============================================================================
# INTEGRATION TESTS
# =============================================================================

validate_integration() {
  test_start "Integration Testing"
  
  # Test explicit sourcing (simulate what fzf does)
  test_info "Testing explicit sourcing in subshell..."
  
  local test_script="
    source '$DOTFILES/zsh/productivity/fzf_profile.sh' || exit 1
    type fdata-profile >/dev/null 2>&1 || exit 1
    echo 'Functions available in subshell'
  "
  
  if eval "$test_script" >/dev/null 2>&1; then
    test_pass "Explicit sourcing works in subshell (fzf context)"
  else
    test_fail "Explicit sourcing fails in subshell"
  fi
  
  # Test function interaction
  test_info "Testing function interaction..."
  
  source "$DOTFILES/zsh/specials/fzf_data.sh" 2>/dev/null
  source "$DOTFILES/zsh/productivity/fzf_profile.sh" 2>/dev/null
  
  if type fdata-preview >/dev/null 2>&1 && type fdata-profile >/dev/null 2>&1; then
    test_pass "Both Phase 1 and Phase 2+3 functions available together"
  else
    test_fail "Function interaction failed"
  fi
}

# =============================================================================
# MOCK DATA TESTS
# =============================================================================

validate_with_mock_data() {
  test_start "Mock Data Testing"
  
  # Create temporary test files
  local temp_dir="/tmp/fzf_profile_test_$$"
  mkdir -p "$temp_dir"
  
  # Create test files
  echo "id,name,value" > "$temp_dir/test.csv"
  echo '{"test": "data"}' > "$temp_dir/test.json"
  echo "test: data" > "$temp_dir/test.yaml"
  
  test_info "Created test files in: $temp_dir"
  
  # Source both systems
  source "$DOTFILES/zsh/specials/fzf_data.sh" 2>/dev/null
  source "$DOTFILES/zsh/productivity/fzf_profile.sh" 2>/dev/null
  
  # Test file analysis
  if type _analyze_data_file >/dev/null 2>&1; then
    local analysis_output
    analysis_output=$(_analyze_data_file "$temp_dir/test.csv" 2>&1)
    if [[ $? -eq 0 && -n "$analysis_output" ]]; then
      test_pass "_analyze_data_file works with test CSV"
    else
      test_fail "_analyze_data_file failed with test CSV"
    fi
  else
    test_fail "_analyze_data_file function not available"
  fi
  
  # Test compatibility checking (if config loaded)
  if type get_compatible_profiles >/dev/null 2>&1; then
    local compat_output
    compat_output=$(get_compatible_profiles "$temp_dir/test.csv" "$temp_dir/test.json" 2>&1)
    if [[ $? -eq 0 ]]; then
      test_pass "get_compatible_profiles works with test files"
    else
      test_warn "get_compatible_profiles failed (expected if no config)"
    fi
  fi
  
  # Cleanup
  rm -rf "$temp_dir"
  test_info "Cleaned up test files"
}

# =============================================================================
# PERFORMANCE TESTS
# =============================================================================

validate_performance() {
  test_start "Performance Testing"
  
  # Test sourcing time
  local start_time=$(date +%s.%N)
  source "$DOTFILES/zsh/specials/fzf_data.sh" >/dev/null 2>&1
  local fzf_data_time=$(echo "$(date +%s.%N) - $start_time" | bc)
  
  start_time=$(date +%s.%N)
  source "$DOTFILES/zsh/productivity/fzf_profile.sh" >/dev/null 2>&1
  local fzf_profile_time=$(echo "$(date +%s.%N) - $start_time" | bc)
  
  test_info "fzf_data.sh sourcing time: ${fzf_data_time}s"
  test_info "fzf_profile.sh sourcing time: ${fzf_profile_time}s"
  
  # Check if times are reasonable (under 1 second)
  if (( $(echo "$fzf_data_time < 1.0" | bc -l) )); then
    test_pass "fzf_data.sh loads quickly (<1s)"
  else
    test_warn "fzf_data.sh loads slowly (>1s)"
  fi
  
  if (( $(echo "$fzf_profile_time < 1.0" | bc -l) )); then
    test_pass "fzf_profile.sh loads quickly (<1s)"
  else
    test_warn "fzf_profile.sh loads slowly (>1s)"
  fi
}

# =============================================================================
# MAIN VALIDATION RUNNER
# =============================================================================

run_all_validations() {
  echo -e "${CYAN}🔍 Profile System Validation${NC}"
  echo "=============================="
  echo "Testing separated fzf_data.sh and fzf_profile.sh"
  echo ""
  
  # Run all validation tests
  validate_environment
  validate_file_structure
  validate_syntax
  validate_fzf_data_functions
  validate_fzf_profile_functions
  validate_configuration_system
  validate_profile_discovery
  validate_integration
  validate_with_mock_data
  validate_performance
  
  # Summary
  echo -e "\n${CYAN}📊 Test Summary${NC}"
  echo "==============="
  echo -e "Total tests: ${BLUE}$TESTS_TOTAL${NC}"
  echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
  echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All tests passed! The profile system separation is working correctly.${NC}"
    return 0
  else
    echo -e "\n${RED}❌ Some tests failed. Check the output above for details.${NC}"
    return 1
  fi
}

# =============================================================================
# INDIVIDUAL TEST RUNNERS
# =============================================================================

# Allow running individual test suites
case "${1:-all}" in
  "env"|"environment")
    validate_environment
    ;;
  "files"|"structure")
    validate_file_structure
    ;;
  "syntax")
    validate_syntax
    ;;
  "functions")
    validate_fzf_data_functions
    validate_fzf_profile_functions
    ;;
  "config"|"configuration")
    validate_configuration_system
    ;;
  "discovery")
    validate_profile_discovery
    ;;
  "integration")
    validate_integration
    ;;
  "mock"|"data")
    validate_with_mock_data
    ;;
  "performance"|"perf")
    validate_performance
    ;;
  "all"|"")
    run_all_validations
    ;;
  "help"|"-h"|"--help")
    echo "Usage: $0 [test_suite]"
    echo ""
    echo "Test suites:"
    echo "  env          - Environment validation"
    echo "  files        - File structure validation"
    echo "  syntax       - Syntax validation"
    echo "  functions    - Function availability"
    echo "  config       - Configuration system"
    echo "  discovery    - Profile discovery"
    echo "  integration  - Integration testing"
    echo "  mock         - Mock data testing"
    echo "  performance  - Performance testing"
    echo "  all          - Run all tests (default)"
    ;;
  *)
    echo "Unknown test suite: $1"
    echo "Use '$0 help' for available options"
    exit 1
    ;;
esac
