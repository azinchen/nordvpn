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
# Format in Dockerfile (using TARGETPLATFORM from buildx):
#   # PLATFORM_VERSIONS: <package-name>: <platform1>=<version1> <platform2>=<version2> ...
#   <package>_version=$(case "${TARGETPLATFORM:-linux/amd64}" in \
#       <platform1>)    echo "<version1>"  ;; \
#       <platform2>    echo "<version2>"  ;; \
#       *)              echo "<default-version>" ;; esac) && \
#   apk --no-cache --no-progress add \
#       <package>=${<package>_version} \
#
# Platform names:
#   - Use "default" for the wildcard (*) case (linux/amd64 and other platforms)
#   - Use TARGETPLATFORM values: linux/amd64, linux/arm64, linux/arm/v7, linux/arm/v6,
#     linux/386, linux/ppc64le, linux/s390x, linux/riscv64
#   - The script automatically maps TARGETPLATFORM values to Alpine package repository architectures
#
# Example:
#   # PLATFORM_VERSIONS: bind-tools: default=9.20.15-r0 linux/riscv64=9.20.13-r0
#   bind_tools_version=$(case "${TARGETPLATFORM:-linux/amd64}" in \
#       linux/riscv64)  echo "9.20.13-r0"  ;; \
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
#   - Check versions for "default" platform against x86_64 packages
#   - Check versions for other platforms against their specific Alpine repository architectures
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

# --- 3b. Function to Map TARGETPLATFORM to Alpine Package Repository Architecture ---
# Based on TARGETPLATFORM values from Docker buildx and actual Alpine repository usage:
# - linux/amd64    -> x86_64
# - linux/386      -> x86
# - linux/arm64    -> aarch64
# - linux/arm/v7   -> armv7 (NOT armhf!)
# - linux/arm/v6   -> armhf
# - linux/ppc64le  -> ppc64le
# - linux/s390x    -> s390x
# - linux/riscv64  -> riscv64
map_targetplatform_to_alpine_arch()
{
    local platform="$1"
    
    case "$platform" in
        linux/amd64)    echo "x86_64"   ;;
        linux/386)      echo "x86"      ;;
        linux/arm64*)   echo "aarch64"  ;;
        linux/arm/v7)   echo "armv7"    ;;
        linux/arm/v6)   echo "armhf"    ;;
        linux/arm*)     echo "armhf"    ;;
        linux/ppc64le)  echo "ppc64le"  ;;
        linux/s390x)    echo "s390x"    ;;
        linux/riscv64)  echo "riscv64"  ;;
        default)        echo "x86_64"   ;;
        *)              echo "x86_64"   ;;
    esac
}

# --- 3c. Legacy function for backward compatibility with uname -m ---
# This function maps uname -m output to Alpine Package Repository Architecture
map_uname_to_alpine_arch()
{
    local uname_arch="$1"
    
    case "$uname_arch" in
        x86_64)         echo "x86_64"   ;;
        i?86|i386|i686) echo "x86"      ;;
        aarch64)        echo "aarch64"  ;;
        armv7l)         echo "armv7"    ;;
        armv6l)         echo "armhf"    ;;
        ppc64le)        echo "ppc64le"  ;;
        riscv64)        echo "riscv64"  ;;
        s390x)          echo "s390x"    ;;
        *)              echo "$uname_arch" ;;
    esac
}

# --- 3c. Function to Extract Version for Specific Architecture ---
extract_version_for_arch()
{
    local pkg="$1"
    local arch="$2"
    local alpine_arch
    local url
    
    # Map uname architecture to Alpine package repository architecture
    alpine_arch=$(map_uname_to_alpine_arch "$arch")
    
    # Try main repository first
    url="https://pkgs.alpinelinux.org/package/v${ALPINE_BRANCH}/main/${alpine_arch}/${pkg}"
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
        url="https://pkgs.alpinelinux.org/package/v${ALPINE_BRANCH}/community/${alpine_arch}/${pkg}"
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
    # Process in reverse order so line number deletions don't affect earlier entries
    temp_file=$(mktemp)
    echo "$platform_lines" | sort -t: -k1 -nr > "$temp_file"
    
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
        
        # Extract default version for comparison
        default_version=$(echo "$updated_line" | grep -o 'default=[^ ]*' | cut -d'=' -f2)
        
        # Remove platform-specific entries that match the default version
        archs_to_remove=""
        if [ -n "$default_version" ]; then
            cleaned_line="# PLATFORM_VERSIONS: $pkg_name: default=$default_version"
            has_cleanup=0
            
            for pair in $(echo "$updated_line" | sed -E 's/.*: //' | tr ' ' '\n'); do
                arch=$(echo "$pair" | cut -d'=' -f1)
                version=$(echo "$pair" | cut -d'=' -f2)
                
                if [ "$arch" != "default" ]; then
                    if [ "$version" = "$default_version" ]; then
                        echo "  ℹ Removing $arch (same as default: $default_version)"
                        has_cleanup=1
                        archs_to_remove="$archs_to_remove $arch"
                    else
                        cleaned_line="$cleaned_line $arch=$version"
                    fi
                fi
            done
            
            updated_line="$cleaned_line"
            
            if [ $has_cleanup -eq 1 ]; then
                has_platform_update=1
            fi
        fi
        
        # Check if all platform-specific versions are the same
        all_versions=$(echo "$updated_line" | sed -E 's/.*: //' | tr ' ' '\n' | cut -d'=' -f2 | sort -u)
        version_count=$(echo "$all_versions" | wc -l)
        
        if [ "$version_count" -eq 1 ]; then
            # All versions are the same - convert to regular package format
            common_version=$(echo "$all_versions" | head -1)
            echo "  ℹ All architectures use the same version ($common_version)"
            echo "  Converting to regular package format..."
            
            # Find the package variable name (e.g., bind_tools_version)
            var_name="${pkg_name}_version"
            var_name=$(echo "$var_name" | tr '-' '_')
            
            # Remove the PLATFORM_VERSIONS comment line
            sed -i "${line_num}d" "$DOCKERFILE"
            
            # Remove the case statement (find lines between variable assignment and apk add)
            # Find the line with the variable assignment
            case_start_line=$(grep -n "${var_name}=\$(case" "$DOCKERFILE" | cut -d: -f1 | head -1)
            if [ -n "$case_start_line" ]; then
                # Find the closing ;; esac) line
                case_end_line=$(awk "NR>$case_start_line && /;; esac\)/ {print NR; exit}" "$DOCKERFILE")
                if [ -n "$case_end_line" ]; then
                    # Delete the case statement lines
                    sed -i "${case_start_line},${case_end_line}d" "$DOCKERFILE"
                fi
            fi
            
            # Replace the variable reference with the actual version
            sed -i "s/${pkg_name}=\${${var_name}}/${pkg_name}=${common_version}/" "$DOCKERFILE"
            
            echo "  ✓ Converted $pkg_name to regular format with version $common_version"
            UPDATED_COUNT=$((UPDATED_COUNT + 1))
            if [ -z "$UPDATED_PACKAGES" ]; then
                UPDATED_PACKAGES="- $pkg_name (converted to regular format: $common_version)"
            else
                UPDATED_PACKAGES="$UPDATED_PACKAGES
- $pkg_name (converted to regular format: $common_version)"
            fi
        else
            # Remove case statement lines for architectures that match default
            if [ -n "$archs_to_remove" ]; then
                for arch in $archs_to_remove; do
                    sed -i "/^[[:space:]]*${arch})[[:space:]]*echo/d" "$DOCKERFILE"
                done
            fi
            
            # Update the comment line with new versions if there were updates
            if [ $has_platform_update -eq 1 ]; then
                # Preserve indentation from original line
                indent=$(echo "$line_content" | sed -n 's/^\([[:space:]]*\)#.*/\1/p')
                escaped_new=$(echo "${indent}${updated_line}" | sed 's/[&/\]/\\&/g')
                sed -i "${line_num}s/.*/${escaped_new}/" "$DOCKERFILE"
            fi
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

