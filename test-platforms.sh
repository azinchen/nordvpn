#!/bin/bash
# Test script to build and verify all supported platforms using TARGETPLATFORM

set -e

PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "linux/arm/v7"
    "linux/arm/v6"
    "linux/386"
    "linux/ppc64le"
    "linux/s390x"
    "linux/riscv64"
)

echo "=========================================="
echo "Building and testing all platforms"
echo "Using TARGETPLATFORM from buildx"
echo "=========================================="
echo ""

for platform in "${PLATFORMS[@]}"; do
    # Clean platform name for tag
    tag=$(echo "$platform" | sed 's/\//-/g' | sed 's/linux-//')
    
    echo ">>> Building for $platform (tag: nordvpn:$tag-test)"
    
    # Build the image
    if docker build --platform "$platform" -t "nordvpn:$tag-test" . > /tmp/build-$tag.log 2>&1; then
        echo "✓ Build successful"
        
        # Check build log for TARGETPLATFORM
        if grep -q "Target platform: $platform" /tmp/build-$tag.log; then
            echo "✓ TARGETPLATFORM correctly passed: $platform"
        else
            echo "⚠ TARGETPLATFORM not found in build log"
        fi
        
        # Test uname in the container
        uname_output=$(docker run --rm --entrypoint /bin/sh "nordvpn:$tag-test" -c "uname -m" 2>/dev/null || echo "FAILED")
        
        if [ "$uname_output" != "FAILED" ]; then
            echo "✓ Container uname -m: $uname_output"
            
            # Check if s6-overlay binaries exist
            if docker run --rm --entrypoint /bin/sh "nordvpn:$tag-test" -c "ls /command/s6-svscan > /dev/null 2>&1"; then
                echo "✓ s6-overlay binaries present"
            else
                echo "✗ s6-overlay binaries missing!"
            fi
        else
            echo "✗ Failed to run container"
        fi
    else
        echo "✗ Build failed - see /tmp/build-$tag.log"
        tail -30 /tmp/build-$tag.log
    fi
    
    echo ""
done

echo "=========================================="
echo "Build Summary"
echo "=========================================="
docker images | grep "nordvpn.*test" | awk '{printf "%-30s %s\n", $1":"$2, $7}'
