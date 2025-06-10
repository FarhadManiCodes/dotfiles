# 1. Install dependencies
sudo apt update
sudo apt install -y git meson ninja-build pkg-config bison flex \
    libxcb-dev libx11-dev libxkbcommon-dev libxcb-xkb-dev

# 2. Clone repository (use specific tag for 1.10.0)
git clone --depth 1 --branch xkbcommon-1.10.0 https://github.com/xkbcommon/libxkbcommon.git
cd libxkbcommon

# 3. Configure build with moderate optimizations
meson setup build \
    --prefix=/usr/local \
    --buildtype=release \
    -Doptimization=2 \
    -Db_ndebug=true \
    -Dc_args="-march=native -O2" \
    -Dcpp_args="-march=native -O2" \
    -Db_lto=true

# 4. Compile and install
ninja -C build
sudo ninja -C build install

# 5. Update linker cache
sudo ldconfig
