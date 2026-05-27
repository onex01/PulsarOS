#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

echo "=== PulsarOS Build Environment Setup ==="
sudo apt update
sudo apt install -y \
    git-core gnupg flex bison build-essential zip curl \
    zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
    libncurses5 lib32ncurses5-dev x11proto-core-dev \
    libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils \
    xsltproc unzip fontconfig python3 python-is-python3 \
    openjdk-11-jdk ccache rsync

mkdir -p ~/.local/bin
if [[ ! -f ~/.local/bin/repo ]]; then
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.local/bin/repo
    chmod a+x ~/.local/bin/repo
fi

echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo "Done. Restart shell or run: source ~/.bashrc"