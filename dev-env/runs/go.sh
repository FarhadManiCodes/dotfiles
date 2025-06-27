#!/usr/bin/env bash
set -euo pipefail

#------------- Configuration -------------
GO_VERSION="1.24.4"
GO_DIST="go${GO_VERSION}.linux-amd64.tar.gz"
DOWNLOAD_URL="https://go.dev/dl/${GO_DIST}"
# Official SHA256 from https://go.dev/dl/ :contentReference[oaicite:0]{index=0}
SHA256_SUM="77e5da33bb72aeaef1ba4418b6fe511bc4d041873cbf82e5aa6318740df98717"

#------------- Prerequisites -------------
if [ "$(id -u)" -ne 0 ]; then
  echo "⚠️  Please run this script as root (sudo)."
  exit 1
fi

apt-get update
apt-get install -y wget tar

#------------- Download & Verify -------------
cd /tmp
wget -q "${DOWNLOAD_URL}"
echo "${SHA256_SUM}  ${GO_DIST}" | sha256sum -c -

#------------- Install Go -------------
rm -rf /usr/local/go
tar -C /usr/local -xzf "${GO_DIST}"

#------------- Environment Setup -------------
cat << 'EOF' >/etc/profile.d/go.sh
# Go environment (added by install_go.sh)
export GOPATH="$HOME/go"
export GOCACHE="$HOME/.cache/go-build"
export GOMAXPROCS=$(nproc)
export GOGC=200
export PATH="/usr/local/go/bin:${GOPATH}/bin:$PATH"
EOF
chmod +x /etc/profile.d/go.sh

#------------- Activate & Verify -------------
# shellcheck disable=SC1091
source /etc/profile.d/go.sh
echo "✅ Installed Go:"
go version
