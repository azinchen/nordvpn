#!/bin/sh
# shellcheck shell=sh
# scripts/update-apk-versions.sh
# This script extracts package names and versions from a specified Dockerfile,
# checks for updates from Alpine package repositories (main first, then community),
# and updates the Dockerfile if necessary.
# Usage: ./scripts/update-apk-versions.sh <path/to/Dockerfile>
# If no argument is provided, it defaults to "Dockerfile" in the current directory.

set -eu

DOCKERFILE="${1:-Dockerfile}"

if [ ! -f "$DOCKERFILE" ]; then
  echo "Error: Dockerfile not found at '$DOCKERFILE'"
  exit 1
fi

# --- 1. Extract Alpine Version from Dockerfile ---
ALPINE_VERSION_FULL=$(grep '^FROM alpine:' "$DOCKERFILE" | head -n1 | sed -E 's/FROM alpine:(.*)/\1/')
ALPINE_BRANCH=$(echo "$ALPINE_VERSION_FULL" | cut -d. -f1,2)
echo "Using Alpine branch version: $ALPINE_BRANCH"

# --- 2. Extract Package List from Dockerfile ---
joined_content=$(sed ':a;N;$!ba;s/\\\n/ /g' "$DOCKERFILE")
package_lines=$(echo "$joined_content" | grep -oP 'apk --no-cache --no-progress add\s+\K[^&]+')
packages=$(echo "$package_lines" | tr ' ' '\n' | sed '/^\s*$/d' | sort -u)

echo "Found packages in $DOCKERFILE:"
echo "$packages"
echo

# --- 3. Function to Precisely Extract Version from HTML using AWK ---
extract_new_version()
{
    local url="$1"
    local html
    html=$(curl -s "$url")
    local version
    version=$(echo "$html" | awk 'BEGIN { RS="</tr>"; FS="\n" } 
      /<th class="header">Version<\/th>/ {
         if (match($0, /<strong>([^<]+)<\/strong>/, a)) {
            print a[1]
         }
      }' | head -n 1)
    echo "$version"
}

# --- 4. Initialize variables to track updates ---
UPDATED_PACKAGES=""
TOTAL_PACKAGES=0
UPDATED_COUNT=0

# --- 5. Modified update_package function to track changes ---
update_package_with_tracking() {
    pkg_with_version="$1"  # e.g., tar=1.35-r2
    TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
    
    if [ -n "$pkg_with_version" ] && [ "${pkg_with_version#*=}" != "$pkg_with_version" ]; then
        pkg=$(echo "$pkg_with_version" | cut -d'=' -f1)
        current_version=$(echo "$pkg_with_version" | cut -d'=' -f2)
    else
        pkg="$pkg_with_version"
        current_version=""
    fi

    # First try the "main" repository.
    URL="https://pkgs.alpinelinux.org/package/v${ALPINE_BRANCH}/main/x86_64/${pkg}"
    echo "Checking package '$pkg' (current version: $current_version) from: $URL"
    new_version=$(extract_new_version "$URL")
    repo="main"

    # If not found in main, try the "community" repository.
    if [ -z "$new_version" ]; then
        URL="https://pkgs.alpinelinux.org/package/v${ALPINE_BRANCH}/community/x86_64/${pkg}"
        echo "  Not found in main, trying community: $URL"
        new_version=$(extract_new_version "$URL")
        repo="community"
    fi

    if [ -z "$new_version" ]; then
        echo "  Could not retrieve new version for '$pkg' from either repository. Skipping."
        return
    fi

    if [ "$current_version" != "$new_version" ]; then
        echo "  Updating '$pkg' from $current_version to $new_version (found in $repo repo)"
        sed -i "s/${pkg}=${current_version}/${pkg}=${new_version}/g" "$DOCKERFILE"
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
        if [ -z "$UPDATED_PACKAGES" ]; then
            UPDATED_PACKAGES="- $pkg ($current_version → $new_version)"
        else
            UPDATED_PACKAGES="$UPDATED_PACKAGES
- $pkg ($current_version → $new_version)"
        fi
    else
        echo "  '$pkg' is up-to-date ($current_version)."
    fi
    echo
}

# --- 6. Loop Over All Packages and Update ---
IFS='
'
for package in $packages; do
    update_package_with_tracking "$package"
done
unset IFS

# --- 7. Output summary ---
echo "=== UPDATE SUMMARY ==="
echo "Total packages checked: $TOTAL_PACKAGES"
echo "Packages updated: $UPDATED_COUNT"

if [ $UPDATED_COUNT -gt 0 ]; then
    echo "Updated packages:"
    echo "$UPDATED_PACKAGES"
    echo "✅ SUCCESS: $UPDATED_COUNT package(s) were updated."
    UPDATE_EXIT_CODE=0
else
    echo "No packages were updated."
    echo "✅ All packages are up-to-date."
    UPDATE_EXIT_CODE=0
fi

# Set GitHub Actions environment variables and outputs (only if running in GitHub Actions)
if [ -n "${GITHUB_ENV:-}" ]; then
    {
        echo "TOTAL_PACKAGES=$TOTAL_PACKAGES"
        echo "UPDATED_COUNT=$UPDATED_COUNT"
        
        if [ $UPDATED_COUNT -gt 0 ]; then
            echo "PACKAGES_UPDATED<<EOF"
            echo "$UPDATED_PACKAGES"
            echo "EOF"
            echo "HAS_UPDATES=true"
        else
            echo "PACKAGES_UPDATED=No packages needed updates"
            echo "HAS_UPDATES=false"
        fi
    } >> "$GITHUB_ENV"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "total_packages=$TOTAL_PACKAGES"
        echo "updated_count=$UPDATED_COUNT"
        
        if [ $UPDATED_COUNT -gt 0 ]; then
            echo "packages_updated<<EOF"
            echo "$UPDATED_PACKAGES"
            echo "EOF"
            echo "has_updates=true"
        else
            echo "packages_updated=No packages needed updates"
            echo "has_updates=false"
        fi
    } >> "$GITHUB_OUTPUT"
fi

# Exit with appropriate code
exit $UPDATE_EXIT_CODE

