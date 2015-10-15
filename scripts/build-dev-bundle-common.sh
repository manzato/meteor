#!/usr/bin/env bash

set -e
set -u

UNAME=$(uname)
ARCH=$(uname -m)

# save number of processors to define max parallelism for build processes
NPROCESSORS=$(getconf _NPROCESSORS_ONLN)

# The METEOR_UNIVERSAL_FLAG will save the indicator how to handle unofficially
# support environments. For armvXl boards we are support pre built binaries from
# bintray. For all other systems we check, that there are system binries available
# for node and mongo. If METEOR_UNIVERSAL_FLAG is not set, then this runs as same 
# as official meteor installer and starter
METEOR_UNIVERSAL_FLAG=

if [ "$UNAME" == "Linux" ] ; then
    if [ "$ARCH" != "i686" -a "$ARCH" != "x86_64" ] ; then
        if [ "$ARCH" != "armv6l" -a "$ARCH" != "armv7l" ] ; then
            # set flag that we are in universal system environment support mode
            METEOR_UNIVERSAL_FLAG="ENV"
        else
            # set flag that we are in unofficial ARM support mode
            METEOR_UNIVERSAL_FLAG="ARM"
        fi
    fi

    OS="linux"

    stripBinary() {
        strip --remove-section=.comment --remove-section=.note $1
    }
elif [ "$UNAME" == "Darwin" ] ; then
    SYSCTL_64BIT=$(sysctl -n hw.cpu64bit_capable 2>/dev/null || echo 0)
    if [ "$ARCH" == "i386" -a "1" != "$SYSCTL_64BIT" ] ; then
        # some older macos returns i386 but can run 64 bit binaries.
        # Probably should distribute binaries built on these machines,
        # but it should be OK for users to run.
        ARCH="x86_64"
    fi

    if [ "$ARCH" != "x86_64" ] ; then
        echo "Unsupported architecture: $ARCH"
        echo "Meteor only supports x86_64 for now."
        exit 1
    fi

    OS="osx"

    # We don't strip on Mac because we don't know a safe command. (Can't strip
    # too much because we do need node to be able to load objects like
    # fibers.node.)
    stripBinary() {
        true
    }
else
    echo "This OS not yet supported"
    exit 1
fi

PLATFORM="${UNAME}_${ARCH}"

SCRIPTS_DIR=$(dirname $0)
cd "$SCRIPTS_DIR/.."
CHECKOUT_DIR=$(pwd)

DIR=$(mktemp -d -t generate-dev-bundle-XXXXXXXX)
trap 'rm -rf "$DIR" >/dev/null 2>&1' 0

cd "$DIR"
chmod 755 .
umask 022
mkdir build
cd build
