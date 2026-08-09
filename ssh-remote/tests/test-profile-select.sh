#!/bin/sh
# Unit-test the deterministic login-profile selection (POSIX).
set -u
# shellcheck disable=SC1007
SELECT="$(CDPATH= cd "$(dirname "$0")/../bundle/shell" && pwd)/profile-select.sh"
fails=0

run_case() { # $1=label  $2=expected  $3...=files to create
  label=$1; expected=$2; shift 2
  H=$(mktemp -d)
  for f in "$@"; do printf 'marker\n' > "$H/$f"; done
  got=$( HOME="$H" _DFR_SKIP_ETC=1 sh -c '. "$0"; _dfr_source_first_profile >/dev/null 2>&1; printf "%s" "$_DFR_SOURCED"' "$SELECT" )
  rm -rf "$H"
  if [ "$got" = "$expected" ]; then
    printf 'PASS %s (got %s)\n' "$label" "${got:-<none>}"
  else
    printf 'FAIL %s: expected %s, got %s\n' "$label" "$expected" "${got:-<none>}"; fails=$((fails+1))
  fi
}

run_case "bash_profile wins over bashrc" .bash_profile .bash_profile .bashrc
run_case "bash_login when no bash_profile" .bash_login .bash_login .profile .bashrc
run_case "profile when no bash_*"          .profile   .profile .bashrc
run_case "bashrc only as last resort"      .bashrc    .bashrc
run_case "no profiles -> empty"            ""

[ "$fails" -eq 0 ] || { printf '%d failures\n' "$fails"; exit 1; }
printf 'all profile-select tests passed\n'
