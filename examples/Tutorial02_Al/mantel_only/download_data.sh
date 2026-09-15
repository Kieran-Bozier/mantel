#!/bin/bash
# download_data.sh

DATA_URL="https://github.com/Kieran-Bozier/Mantel/releases/download/Tutorial_02_data/mantel_only_files.tar.gz"
TARBALL="mantel_only_files.tar.gz"

if [ -d "WFC" ] && [ -d "YAMBO" ]; then
    echo "Data already present, skipping download."
    exit 0
fi

echo "Downloading tutorial data..."
wget -q --show-progress "$DATA_URL" -O "$TARBALL" || { echo "Download failed"; exit 1; }

echo "Extracting..."
tar xzf "$TARBALL"
rm "$TARBALL"

echo "Done."
