
#!/usr/bin/env bash
# macOS rename verification script
# Checks whether the short name, home folder, and account record are consistent.

set -euo pipefail

echo "==== macOS Rename Verification ===="
printf "\n"

# 1) Current login / UNIX short name
current_user="$(whoami 2>/dev/null || echo UNKNOWN)"
uid="$(id -u 2>/dev/null || echo UNKNOWN)"
echo "1) Current login / UNIX short name:"
echo "   whoami: $current_user"
echo "   uid: $uid"
printf "\n"

# 2) Home environment and folder
home_dir="${HOME:-UNKNOWN}"
echo "2) Home directory:"
echo "   \$HOME: $home_dir"
if [ -d "$home_dir" ]; then
  echo "   Folder: exists"
  ls_output="$(ls -ld "$home_dir" 2>/dev/null || true)"
  echo "   ls -ld: $ls_output"
else
  echo "   Folder: DOES NOT EXIST"
fi
printf "\n"

# 3) Owner reported by filesystem
echo "3) File system ownership:"
if command -v stat >/dev/null 2>&1; then
  fs_owner="$(stat -f '%Su' "$home_dir" 2>/dev/null || echo UNKNOWN)"
  fs_group="$(stat -f '%Sg' "$home_dir" 2>/dev/null || echo UNKNOWN)"
  echo "   Owner: $fs_owner"
  echo "   Group: $fs_group"
else
  echo "   stat command not available"
fi
printf "\n"

# 4) Directory service (dscl) record for current user
echo "4) Directory Service record:"
if command -v dscl >/dev/null 2>&1; then
  dscl_out="$(dscl . -read "/Users/$current_user" NFSHomeDirectory RecordName UniqueID RealName 2>/dev/null || true)"
  if [ -n "$dscl_out" ]; then
    echo "$dscl_out" | sed 's/^/   /'
  else
    echo "   No dscl record found for /Users/$current_user"
  fi
else
  echo "   dscl command not available"
fi
printf "\n"

# 5) Check which user(s) have NFSHomeDirectory = $HOME
echo "5) Users with NFSHomeDirectory = \$HOME:"
if command -v dscl >/dev/null 2>&1; then
  dscl_list="$(dscl . -list /Users NFSHomeDirectory 2>/dev/null || true)"
  if [ -n "$dscl_list" ]; then
    echo "$dscl_list" | awk -v home="$home_dir" '$2==home { print "   matched:", $1, "->", $2 }'
  else
    echo "   Could not list users and home directories"
  fi
else
  echo "   dscl command not available"
fi
printf "\n"

# 6) Summary
echo "==== Summary ===="
ok=true

if [ "$current_user" = "UNKNOWN" ] || [ -z "$current_user" ]; then
  echo " - FAIL: Could not determine current username"
  ok=false
else
  echo " - OK: Current username is $current_user"
fi

if [ ! -d "$home_dir" ]; then
  echo " - FAIL: Home folder $home_dir does not exist"
  ok=false
else
  echo " - OK: Home folder exists"
fi

if [ "$fs_owner" != "$current_user" ]; then
  echo " - WARNING: Home folder owner is '$fs_owner', expected '$current_user'"
  echo "   Suggested fix: sudo chown -R ${current_user}:staff \"$home_dir\""
  ok=false
else
  echo " - OK: Home folder owner matches username"
fi

dscl_home="$(echo "$dscl_out" | awk '/NFSHomeDirectory:/{print $2}' || true)"
if [ -n "$dscl_home" ]; then
  if [ "$dscl_home" = "$home_dir" ]; then
    echo " - OK: dscl NFSHomeDirectory matches $HOME"
  else
    echo " - WARNING: dscl NFSHomeDirectory is '$dscl_home', expected '$home_dir'"
    ok=false
  fi
else
  echo " - NOTE: Could not read dscl NFSHomeDirectory"
fi

printf "\n"
if [ "$ok" = true ]; then
  echo "All checks passed. The account rename appears complete."
else
  echo "Some checks flagged issues. Review the warnings above before making changes."
fi

echo "==== End ===="
