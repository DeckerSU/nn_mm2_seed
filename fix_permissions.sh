#!/bin/bash
# fix_permissions.sh
#
# Grants the current user read/write ACL permissions on MM2.json, kdf.log
# and userpass. These files are created inside the container as the 'komodian'
# user (uid 1000) and may not be accessible by the host user without ACLs.
#
# Requirements: acl package (provides setfacl / getfacl).
#   Debian/Ubuntu: sudo apt-get install acl
#   RHEL/CentOS/Fedora: sudo dnf install acl  (or: sudo yum install acl)
#   Arch Linux: sudo pacman -S acl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES=("MM2.json" "kdf.log" "userpass")
CURRENT_USER="$(id -un)"

# Check that setfacl is available
if ! command -v setfacl &>/dev/null; then
    echo "Error: setfacl is not installed."
    echo ""
    echo "Install it with the package manager for your distribution:"
    echo "  Debian/Ubuntu:       sudo apt-get install acl"
    echo "  RHEL/CentOS/Fedora:  sudo dnf install acl"
    echo "  Arch Linux:          sudo pacman -S acl"
    echo ""
    echo "Note: also make sure the filesystem is mounted with ACL support."
    echo "  Check: tune2fs -l <device> | grep 'Default mount options'"
    echo "  Enable (if needed): sudo tune2fs -o acl <device>"
    exit 1
fi

echo "Applying ACLs for user '${CURRENT_USER}'..."

for file in "${FILES[@]}"; do
    target="${SCRIPT_DIR}/${file}"
    if [ -f "${target}" ]; then
        setfacl -m "u:${CURRENT_USER}:rw" "${target}"
        echo "  [ok] ${file}"
    else
        echo "  [skip] ${file} — file not found (will be created by the container on first run)"
    fi
done

echo "Done."
