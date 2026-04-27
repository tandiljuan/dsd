#!/bin/bash -e

# Build script for Debian Trixie (13)
# @see https://github.com/ohwgiles/laminar/blob/master/pkg/debian13-amd64.sh

set -ex

apt-get update && \
apt-get install -y \
    wget \
    cmake \
    g++ \
    capnproto \
    libcapnp-dev \
    rapidjson-dev \
    libsqlite3-dev \
    libboost-dev \
    zlib1g-dev \
    pkg-config \
    git \
    2>/dev/null

SOURCE_DIR="/laminar"
BUILD_DIR="/build"
TARGET_DIR="/opt"

GIT_REPO="https://github.com/ohwgiles/laminar"
GIT_VERSION="3392b899"

git clone "${GIT_REPO}" "${SOURCE_DIR}"

VERSION=$(cd "${SOURCE_DIR}" && git checkout "${GIT_VERSION}" && git describe --tags --abbrev=8 --dirty)-debian13

mkdir "${BUILD_DIR}" && cd "${BUILD_DIR}"

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DLAMINAR_VERSION=$VERSION \
    -DZSH_COMPLETIONS_DIR=/usr/share/zsh/functions/Completion/Unix \
    /laminar \
    2>/dev/null

make -j4 2>/dev/null

mkdir laminar
make DESTDIR=laminar install/strip

mkdir laminar/DEBIAN

cat <<EOF > laminar/DEBIAN/control
Package: laminar
Version: $VERSION
Section:
Priority: optional
Architecture: amd64
Maintainer: Oliver Giles <web ohwg net>
Depends: libcapnp-1.1.0, libsqlite3-0, zlib1g
Description: Lightweight Continuous Integration Service
EOF

echo /etc/laminar.conf > laminar/DEBIAN/conffiles

cat <<EOF > laminar/DEBIAN/postinst
#!/bin/bash
echo Creating laminar user with home in /var/lib/laminar
useradd -r -d /var/lib/laminar -s /usr/sbin/nologin laminar
mkdir -p /var/lib/laminar/cfg/{jobs,contexts,scripts}
chown -R laminar: /var/lib/laminar
EOF

chmod +x laminar/DEBIAN/postinst

dpkg-deb --build laminar

mv laminar.deb "${TARGET_DIR}/laminar_debian13_amd64.deb"
