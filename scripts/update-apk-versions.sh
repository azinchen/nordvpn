#!/bin/sh
# shellcheck shell=sh
# scripts/update-apk-versions.sh
#
# This script extracts package names and versions from a specified Dockerfile,
# checks for updates from Alpine package repositories (main first, then community),
# and updates the Dockerfile if necessary.
#
# Usage: ./scripts/update-apk-versions.sh <path/to/Dockerfile>
# If no argument is provided, it defaults to "Dockerfile" in the current directory.
#
# REGULAR PACKAGE VERSIONS (NO PLATFORM-SPECIFIC DIFFERENCES)
# ============================================================
# For packages that use the same version across all architectures, use the
# standard apk add format with explicit version pinning.
#
# Format in Dockerfile:
#   apk --no-cache --no-progress add \
#       <package>=<version> \
#       <another-package>=<version> \
#
# Example:
#   apk --no-cache --no-progress add \
#       curl=8.14.1-r2 \
#       iptables=1.8.11-r1 \
#       jq=1.8.0-r0 \
#       openvpn=2.6.14-r0 \
#       && \
#
# The script will:
#   - Automatically detect all packages with version pins (package=version format)
#   - Check the latest version from Alpine repositories (x86_64)
#   - Update package versions in-place when newer versions are available
#   - Skip packages using variables (e.g., ${variable_name})
#
# PLATFORM-SPECIFIC PACKAGE VERSIONS
# ===================================
# For packages that have different versions across architectures, use the
# PLATFORM_VERSIONS comment format. This allows the script to automatically
# check and update versions for each platform.
#
# Format in Dockerfile:
#   # PLATFORM_VERSIONS: <package-name>: <arch1>=<version1> <arch2>=<version2> ...
#   <package>_version=$(case $(uname -m) in \
#       <arch1>)        echo "<version1>"  ;; \
#       <arch2>)        echo "<version2>"  ;; \
#       *)              echo "<default-version>" ;; esac) && \
#   apk --no-cache --no-progress add \
#       <package>=${<package>_version} \
#
# Architecture names:
#   - Use "default" for the wildcard (*) case (typically x86_64 and other platforms)
#   - Use actual uname -m values for specific architectures: armv7, riscv64, etc.
#
# Example:
#   # PLATFORM_VERSIONS: bind-tools: default=9.20.15-r0 armv7=9.20.13-r0 riscv64=9.20.13-r0
#   bind_tools_version=$(case $(uname -m) in \
#       armv7)          echo "9.20.13-r0"  ;; \
#       riscv64)        echo "9.20.13-r0"  ;; \
#       *)              echo "9.20.15-r0" ;; esac) && \
#   apk --no-cache --no-progress add \
#       bind-tools=${bind_tools_version} \
#
# Important formatting rules:
#   1. The PLATFORM_VERSIONS comment must be indented with 4 spaces
#   2. All 'echo' statements in the case statement must align in the same column
#   3. Use 10 spaces between the closing parenthesis and 'echo' for alignment
#   4. Package references using variables (e.g., ${bind_tools_version}) are
#      automatically excluded from regular version checking
#
# The script will:
#   - Check versions for "default" architecture against x86_64 packages
#   - Check versions for other architectures against their specific packages
#   - Update both the comment line and the case statement when new versions are found
#   - Preserve indentation and alignment throughout the update process

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
# Filter out packages with variable references (containing ${ })
packages=$(echo "$package_lines" | tr ' ' '\n' | sed '/^\s*$/d' | grep -v '\${' | sort -u)

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

# --- 3b. Function to Extract Version for Specific Architecture ---
extract_version_for_arch()
{
    local pkg="$1"
    local arch="$2"
    local url
    
    # Try main repository first
    url="https://pkgs.alpinelinux.org/package/v${ALPINE_BRANCH}/main/${arch}/${pkg}"
    local html
    html=$(curl -s "$url")
    local version
    version=$(echo "$html" | awk 'BEGIN { RS="</tr>"; FS="\n" } 
      /<th class="header">Version<\/th>/ {
         if (match($0, /<strong>([^<]+)<\/strong>/, a)) {
            print a[1]
         }
      }' | head -n 1)
    
    # If not found in main, try community
    if [ -z "$version" ]; then
        url="https://pkgs.alpinelinux.org/package/v${ALPINE_BRANCH}/community/${arch}/${pkg}"
        html=$(curl -s "$url")
        version=$(echo "$html" | awk 'BEGIN { RS="</tr>"; FS="\n" } 
          /<th class="header">Version<\/th>/ {
             if (match($0, /<strong>([^<]+)<\/strong>/, a)) {
                print a[1]
             }
          }' | head -n 1)
    fi
    
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

# --- 7. Handle Platform-Specific Package Versions ---
echo "=== Checking Platform-Specific Versions ==="
platform_lines=$(grep -n "# PLATFORM_VERSIONS:" "$DOCKERFILE" || true)

if [ -n "$platform_lines" ]; then
    # Save to temp file to avoid subshell from pipe
    temp_file=$(mktemp)
    echo "$platform_lines" > "$temp_file"
    
    while IFS=: read -r line_num line_content; do
        # Parse the comment line format: # PLATFORM_VERSIONS: package-name: arch1=version1 arch2=version2 ...
        pkg_name=$(echo "$line_content" | sed -E 's/.*# PLATFORM_VERSIONS: ([^:]+):.*/\1/' | xargs)
        
        if [ -z "$pkg_name" ]; then
            continue
        fi
        
        echo "Processing platform-specific package: $pkg_name"
        
        # Extract all architecture-version pairs
        arch_versions=$(echo "$line_content" | sed -E 's/.*# PLATFORM_VERSIONS: [^:]+: (.*)/\1/')
        
        # Parse each arch=version pair
        updated_line="# PLATFORM_VERSIONS: $pkg_name:"
        has_platform_update=0
        
        for pair in $arch_versions; do
            arch=$(echo "$pair" | cut -d'=' -f1)
            current_version=$(echo "$pair" | cut -d'=' -f2)
            
            echo "  Checking $arch: current=$current_version"
            
            # Get the latest version for this architecture
            # Map "default" to x86_64 for package lookup
            lookup_arch="$arch"
            if [ "$arch" = "default" ]; then
                lookup_arch="x86_64"
            fi
            new_version=$(extract_version_for_arch "$pkg_name" "$lookup_arch")
            
            if [ -z "$new_version" ]; then
                echo "    Could not retrieve version for $pkg_name on $arch, keeping current"
                updated_line="$updated_line $arch=$current_version"
            elif [ "$current_version" != "$new_version" ]; then
                echo "    Updating $arch: $current_version → $new_version"
                updated_line="$updated_line $arch=$new_version"
                has_platform_update=1
                
                # Update the case statement in the Dockerfile, preserving alignment
                # For "default", update the "*)" wildcard pattern instead
                if [ "$arch" = "default" ]; then
                    case_pattern='\*'
                else
                    case_pattern="${arch}"
                fi
                
                # Extract the exact spacing from the current line to preserve it
                current_spacing=$(grep "${case_pattern})" "$DOCKERFILE" | sed -n "s/.*${case_pattern})\([[:space:]]*\)echo.*/\1/p" | head -1)
                if [ -z "$current_spacing" ]; then
                    # Default to 10 spaces if not found (to match standard formatting)
                    current_spacing="          "
                fi
                sed -i "s/\(${case_pattern})\)[[:space:]]*echo \"\(${current_version}\)\"/\1${current_spacing}echo \"${new_version}\"/" "$DOCKERFILE"
                
                UPDATED_COUNT=$((UPDATED_COUNT + 1))
                if [ -z "$UPDATED_PACKAGES" ]; then
                    UPDATED_PACKAGES="- $pkg_name ($arch: $current_version → $new_version)"
                else
                    UPDATED_PACKAGES="$UPDATED_PACKAGES
- $pkg_name ($arch: $current_version → $new_version)"
                fi
            else
                echo "    $arch is up-to-date ($current_version)"
                updated_line="$updated_line $arch=$current_version"
            fi
        done
        
        # Update the comment line with new versions if there were updates
        if [ $has_platform_update -eq 1 ]; then
            # Preserve indentation from original line
            indent=$(echo "$line_content" | sed -n 's/^\([[:space:]]*\)#.*/\1/p')
            escaped_new=$(echo "${indent}${updated_line}" | sed 's/[&/\]/\\&/g')
            sed -i "${line_num}s/.*/${escaped_new}/" "$DOCKERFILE"
        fi
        
        echo
    done < "$temp_file"
    
    rm -f "$temp_file"
fi

# --- 8. Output summary ---
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

