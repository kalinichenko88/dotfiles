#!/usr/bin/env zsh
# Unit tests for the bare-form parser and the ssh -G config probe.
emulate -L zsh
here="${0:A:h}"
source "$here/../../zsh/ssh-remote.zsh"   # defines _dfr_* helpers (and ssh(), unused here)

fails=0
check() { # $1=label $2=expected(0/1) $3=actual_rc
  if [[ "$2" == "$3" ]]; then print "PASS $1"; else print "FAIL $1 (want $2 got $3)"; ((fails++)); fi
}

# --- bare-host parser: returns 0 + echoes host only for the bare form ---
host=$(_dfr_bare_host myhost);            check "bare host"            0 $?
[[ "$host" == myhost ]] || { print "FAIL bare host value ($host)"; ((fails++)); }
host=$(_dfr_bare_host user@myhost);       check "user@host"            0 $?
[[ "$host" == user@myhost ]] || { print "FAIL user@host value ($host)"; ((fails++)); }
_dfr_bare_host -p 2222 myhost >/dev/null; check "option => passthrough" 1 $?
_dfr_bare_host myhost uptime >/dev/null;  check "remote cmd => pass"    1 $?
_dfr_bare_host myhost -v >/dev/null;      check "flag after host => pass" 1 $?
_dfr_bare_host -N myhost >/dev/null;      check "-N => passthrough"     1 $?
_dfr_bare_host '' >/dev/null;             check "empty operand => pass" 1 $?
_dfr_bare_host >/dev/null;                check "no operand => pass"    1 $?

# --- config probe: stub _dfr_ssh_config to read a fixture (zsh dynamic scope
# makes `fx` and `here` visible inside the redefined function at call time) ---
probe() { local fx="$1"; _dfr_ssh_config() { cat "$here/fixtures/$fx.txt" }; _dfr_should_passthrough_cfg x; print $? }
check "plain => intercept"          1 "$(probe plain)"
check "remotecommand => passthrough" 0 "$(probe remotecommand)"
check "localforward => passthrough"  0 "$(probe localforward)"
check "remoteforward => passthrough" 0 "$(probe remoteforward)"
check "sessiontype none => pass"     0 "$(probe sessiontype-none)"
check "proxyjump => intercept"       1 "$(probe proxyjump)"
check "localcommand => passthrough"  0 "$(probe localcommand)"
check "forkafterauth => passthrough"  0 "$(probe forkafterauth)"
check "requesttty false => passthrough" 0 "$(probe requesttty-false)"
check "requesttty no (legacy) => passthrough" 0 "$(probe requesttty-no)"

(( fails == 0 )) || { print "$fails failures"; exit 1 }
print "all guard tests passed"
