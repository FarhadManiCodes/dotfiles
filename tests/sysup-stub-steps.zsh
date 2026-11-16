# Sourced by the sysup tests after zsh/functions/sysup.zsh: every step that
# sysup runs by default becomes a no-op, so a test runs only the steps it
# defines again afterwards. A new default step in _sysup_steps belongs here,
# or every sysup test would run it for real. The opt-in steps
# (_sysup_tool_tests, _sysup_podman_images) are left to the tests that ask.
for fn in _sysup_mirrorlist_check _sysup_bgutil _sysup_yts _sysup_herdr \
  _sysup_prune_claude_versions _sysup_plugins _sysup_nvim_health \
  _sysup_fwupd_refresh_if_stale _sysup_pacnew; do
  functions[$fn]=':'
done
