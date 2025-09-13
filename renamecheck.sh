
#!/usr/bin/env bash
# macOS rename check script
# Saves nothing, only prints checks. Run in your normal shell.
set -euo pipefail

echo
echo "==== macOS rename verification script ===="
printf "\n"

# 1) Whoami / id
me="$(whoami 2>/dev/null || echo UNKNOWN)"
me_id="$(id -u 2>/dev/null || echo UNKNOWN)"
echo "1) Current login / UNIX short name:"
echo "   whoami:   $me"
echo "   uid:      $me_id"
printf "\n"

# 2) $HOME and existence
home_env="${HOME:-UNKNOWN}"
echo "2) HOME environment and folder:"
echo "   \$HOME:   $home_env"
if [ -d "$home_env" ]; then
  echo "   Folder:   exists"
else
  echo "   Folder:   DOES NOT EXIST"
fi
ls_output="$(ls -ld "$home_env" 2>/dev/null || true)"
if [ -n "$ls_output" ]; then
  echo "   ls -ld:   $ls_output"
fi
printf "\n"

# 3) Owner of home folder (stat)
echo "3) Owner reported by filesystem (stat):"
if command -v stat >/dev/null 2>&1; then
  # macOS stat -f format
  fs_owner="$(stat -f '%Su' "$home_env" 2>/dev/null || echo UNKNOWN)"
  fs_group="$(stat -f '%Sg' "$home_env" 2>/dev/null || echo UNKNOWN)"
  echo "   owner:    $fs_owner"
  echo "   group:    $fs_group"
else
  echo "   stat not found"
fi
printf "\n"

# 4) What dscl says about the current user
echo "4) Directory service (dscl) record for the current user:"
if command -v dscl >/dev/null 2>&1; then
  # try reading typical fields
  dscl_out="$(dscl . -read "/Users/$me" NFSHomeDirectory RecordName UniqueID RealName 2>/dev/null || true)"
  if [ -n "$dscl_out" ]; then
    echo "$dscl_out" | sed 's/^/   /'
  else
    echo "   No dscl record read for /Users/$me (it may not exist or dscl failed)."
  fi
else
  echo "   dscl command not available"
fi
printf "\n"

# 5) Which user record points to this home directory?
echo "5) Which user(s) have NFSHomeDirectory = \$HOME?"
if command -v dscl >/dev/null 2>&1; then
  # list users with their NFSHomeDirectory and grep for current $HOME
  dscl_list="$(dscl . -list /Users NFSHomeDirectory 2>/dev/null || true)"
  if [ -n "$dscl_list" ]; then
    echo "$dscl_list" | awk -v home="$home_env" '$2==home { print "   matched:", $1, "->", $2 }'
    # Also show any partial matches
    echo
    echo "   (All local users and their home paths — helpful for inspection)"
    echo "$dscl_list" | sed 's/^/   /'
  else
    echo "   could not list users / NFSHomeDirectory (permission or dscl issue)"
  fi
else
  echo "   dscl not available"
fi
printf "\n"

# 6) Quick summary of checks and suggested actions
echo "==== Summary checks ===="
ok=true

# check1: whoami exists
if [ "$me" = "UNKNOWN" ] || [ -z "$me" ]; then
  echo " - FAIL: could not determine current username (whoami)"
  ok=false
else
  echo " - OK: logged-in short name: $me"
fi

# check2: home exists
if [ ! -d "$home_env" ]; then
  echo " - FAIL: home folder $home_env does not exist."
  ok=false
else
  echo " - OK: home folder exists."
fi

# check3: owner matches username
if [ -n "${fs_owner:-}" ] && [ "$fs_owner" != "UNKNOWN" ]; then
  if [ "$fs_owner" != "$me" ]; then
    echo " - WARNING: home folder owner is '$fs_owner' but current user is '$me'."
    ok=false
    suggest_chown="sudo chown -R ${me}:staff \"${home_env}\""
    echo "   Suggested fix (run after confirming):"
    echo "     $suggest_chown"
    echo "   (This will change ownership of everything under the home folder to the current user.)"
  else
    echo " - OK: home folder owner matches username."
  fi
else
  echo " - NOTE: could not determine filesystem owner reliably."
fi

# check4: dscl home path matches $HOME
dscl_home="$(echo "$dscl_out" | awk '/NFSHomeDirectory:/{print $2}' || true)"
if [ -n "$dscl_home" ]; then
  if [ "$dscl_home" = "$home_env" ]; then
    echo " - OK: dscl NFSHomeDirectory for '$me' matches \$HOME."
  else
    echo " - WARNING: dscl NFSHomeDirectory for '$me' is '$dscl_home' (does not match \$HOME = '$home_env')."
    echo "   This means the account record may still point to the old home path."
    echo "   To change it (advanced): use System Settings → Users & Groups → Advanced Options OR use dscl carefully."
    ok=false
  fi
else
  echo " - NOTE: could not read dscl NFSHomeDirectory for user '$me'. (Run 'dscl . -read /Users/$me' manually with admin privileges to inspect.)"
fi

printf "\n"
if [ "$ok" = true ]; then
  echo "✅ Looks good: the common rename checks passed."
else
  echo "⚠️ Some checks flagged issues above. Read suggested fixes and proceed carefully."
fi

echo
echo "If you want me to provide the exact chown or dscl commands tailored to your username, tell me the username you expect and I'll produce them."
echo "==== end ===="
