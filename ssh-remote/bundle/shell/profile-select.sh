# shellcheck shell=sh
# POSIX login-profile selection, shared by the bash trampoline and the tests.
# Matches real login-bash: /etc/profile first, then the FIRST existing of
# bash_profile/bash_login/profile (which conventionally sources ~/.bashrc), and
# only ~/.bashrc if no profile exists. Records the chosen user file in
# $_DFR_SOURCED (for tests). Set $_DFR_SKIP_ETC=1 to skip /etc/profile (tests).
_dfr_source_first_profile() {
  _DFR_SOURCED=""
  # shellcheck disable=SC1091
  if [ -z "${_DFR_SKIP_ETC:-}" ] && [ -r /etc/profile ]; then . /etc/profile; fi
  # shellcheck disable=SC1091
  if   [ -r "$HOME/.bash_profile" ]; then _DFR_SOURCED=.bash_profile; . "$HOME/.bash_profile"
  elif [ -r "$HOME/.bash_login"   ]; then _DFR_SOURCED=.bash_login;   . "$HOME/.bash_login"
  elif [ -r "$HOME/.profile"      ]; then _DFR_SOURCED=.profile;      . "$HOME/.profile"
  elif [ -r "$HOME/.bashrc"       ]; then _DFR_SOURCED=.bashrc;       . "$HOME/.bashrc"
  fi
}
