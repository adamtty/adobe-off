#!/bin/bash
# shellcheck disable=SC2329,SC2016,SC2032  # the stand-ins are called by ./adobe (and sudo is a stand-in too); bash -c bodies use their own $1
# Tests for ./adobe. Every system command it runs is replaced by a function that records the call,
# so nothing is really stopped and no Adobe software is needed. Run: tests/test.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
# shellcheck source=SCRIPTDIR/../adobe
source ./adobe

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
FAILED=0
PS_OUT=""

# --- stand-ins for the system commands ---------------------------------------------------------
ps() { printf '%s\n' "$PS_OUT"; }
kill() { echo "kill $*" >>"$LOG"; }
sudo() {
	echo "sudo $*" >>"$LOG"
	[[ $1 == -v ]] && return "${SUDO_OK:-0}"
	return 0
}
launchctl() {
	echo "launchctl $*" >>"$LOG"
	[[ $1 == print-disabled ]] && printf '%s\n' "${DISABLED_OUT:-}"
	return 0
}
pluginkit() { echo "pluginkit $*" >>"$LOG"; }
osascript() { echo "osascript $*" >>"$LOG"; }
open() { echo "open $*" >>"$LOG"; }
sleep() { :; }
# pretend Adobe Genuine Service's daemon and the agents' plists are installed
daemons_present() { echo com.adobe.agsservice; }
plist_for() { echo "/Library/LaunchAgents/$1.plist"; }

U=$UID_
PS_BG="101 $U /Library/Application Support/Adobe/Adobe Desktop Common/ADS/Adobe Desktop Service.app/Contents/MacOS/Adobe Desktop Service
102 $U /Applications/Utilities/Adobe Sync/CoreSync/Core Sync.app/Contents/MacOS/Core Sync
103 $U /Applications/Utilities/Adobe Creative Cloud Experience/CCXProcess/CCXProcess.app/Contents/MacOS/Creative Cloud Content Manager.node
104 0 /Library/Application Support/Adobe/AdobeGCClient/AGSService
105 0 /Library/PrivilegedHelperTools/com.adobe.acc.installer.v2
106 $U $HOME/Library/Application Support/Adobe/OOBE/PDApp.app/Contents/MacOS/PDApp"
# things that must never be signalled
PS_SAFE="201 $U /usr/bin/vim
202 $U /tmp/Adobe Desktop Service
203 $U /Users/someone/Library/Application Support/Adobe/x
204 0 /usr/libexec/Library/Application Support/Adobe/fake
205 $U /bin/bash"
PS_PHOTOSHOP="301 $U /Applications/Adobe Photoshop 2026/Adobe Photoshop 2026.app/Contents/MacOS/Adobe Photoshop 2026
302 $U /Applications/Adobe Photoshop 2026/Adobe Photoshop 2026.app/Contents/MacOS/LogTransport2.app/Contents/MacOS/LogTransport2"

# --- helpers -----------------------------------------------------------------------------------
check() {  # check <description> <command...>: passes when the command succeeds
	local desc=$1
	shift
	if "$@"; then
		echo "ok   $desc"
	else
		echo "FAIL $desc"
		FAILED=1
	fi
}
logged() { grep -qF -- "$1" "$LOG"; }
not_logged() { ! grep -qF -- "$1" "$LOG"; }
run() {  # run <args...>: fresh log, run main, keep output and status
	: >"$LOG"
	OUT=$(main "$@" 2>&1)
	STATUS=$?
}

# --- background() / creative_apps() ------------------------------------------------------------
PS_OUT="$PS_BG
$PS_SAFE
$PS_PHOTOSHOP"
bg_pids=$(background | awk '{print $1}' | tr '\n' ' ')
check "background finds every background process" [ "$bg_pids" = "101 102 103 104 105 106 " ]
check "creative apps are found by bundle" [ "$(creative_apps)" = "Adobe Photoshop 2026" ]

# --- off with a creative app open ---------------------------------------------------------------
run off
check "off refuses while Photoshop is open" [ "$STATUS" = 1 ]
check "  and says why" grep -q "Adobe Photoshop 2026" <<<"$OUT"
check "  and touches nothing" [ ! -s "$LOG" ]

# --- off --force --------------------------------------------------------------------------------
run off --force
check "off --force succeeds" [ "$STATUS" = 0 ]
check "  boots out the login agents" logged "launchctl bootout gui/$U/com.adobe.AdobeDesktopService"
check "  doesn't disable them (no --persist)" not_logged "launchctl disable"
check "  disables the Finder extensions" logged "pluginkit -e ignore -i com.adobe.accmac.ACCFinderSync"
check "  TERMs the user's background processes" logged "kill -TERM 101 102 103 106"
check "  then KILLs what's left" logged "kill -KILL 101 102 103 106"
check "  stops the root daemon with sudo" logged "sudo launchctl bootout system/com.adobe.agsservice"
check "  kills root processes with sudo" logged "sudo kill -KILL 104 105"
for pid in 201 202 203 204 205 301 302; do
	check "  never signals pid $pid" bash -c "! grep -E '^(sudo )?kill .*\\b$pid\\b' '$LOG'"
done

# --- off --persist -------------------------------------------------------------------------------
PS_OUT="$PS_BG
$PS_SAFE"
run off --persist
check "off --persist succeeds with no creative app open" [ "$STATUS" = 0 ]
check "  disables the login agents" logged "launchctl disable gui/$U/com.adobe.AdobeCreativeCloud"
check "  disables the system daemon" logged "sudo launchctl disable system/com.adobe.agsservice"

# root work is skipped cleanly when sudo gets no password
SUDO_OK=1 run off
check "off without sudo still stops the user's processes" logged "kill -TERM 101 102 103 106"
check "  and skips the root ones" not_logged "sudo kill"
check "  and says so" grep -q "skipped" <<<"$OUT"

# nothing root-owned running and no --persist: no password prompt at all
PS_OUT="$PS_SAFE"
run off
check "off with nothing running doesn't ask for sudo" not_logged "sudo"
check "  and signals nothing" not_logged "kill"

# --- on ------------------------------------------------------------------------------------------
run on
check "on succeeds" [ "$STATUS" = 0 ]
check "  re-enables the login agents" logged "launchctl enable gui/$U/com.adobe.ccxprocess"
check "  starts them again" logged "launchctl bootstrap gui/$U /Library/LaunchAgents/com.adobe.ccxprocess.plist"
check "  re-enables the system daemon" logged "sudo launchctl enable system/com.adobe.agsservice"
check "  re-enables the Finder extensions" logged "pluginkit -e use -i com.adobe.accmac.ACCFinderSync"
check "  opens Creative Cloud" logged "open -a Creative Cloud"

# --- status and arguments ------------------------------------------------------------------------
PS_OUT="$PS_BG"
DISABLED_OUT='	"com.adobe.ccxprocess" => disabled
	"com.adobe.GC.AGM" => enabled'
run status
check "status counts background processes" grep -q "Adobe background processes: 6" <<<"$OUT"
check "  marks root ones" grep -q "AGSService (root)" <<<"$OUT"
check "  lists disabled jobs only" bash -c 'grep -q "com.adobe.ccxprocess" <<<"$1" && ! grep -q "GC.AGM" <<<"$1"' _ "$OUT"
run off --bogus
check "unknown option is refused" [ "$STATUS" = 2 ]
run on extra
check "on takes no arguments" [ "$STATUS" = 2 ]
run nonsense
check "unknown command is refused" [ "$STATUS" = 2 ]

[ "$FAILED" = 0 ] && echo "all passed"
exit "$FAILED"
