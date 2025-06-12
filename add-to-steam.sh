#!/bin/bash
# Adds Minecraft Splitscreen as a non-Steam game with SteamGridDB artwork
# to the current user's Steam shortcuts.vdf

APPNAME="Minecraft Splitscreen"
EXE="/home/deck/.local/share/PollyMC/minecraft.sh"
STARTDIR="/home/deck/.local/share/PollyMC"

STEAMGRIDDB_IMAGES=(
  "https://cdn2.steamgriddb.com/grid/a73027901f88055aaa0fd1a9e25d36c7.png"
  "https://cdn2.steamgriddb.com/grid/e353b610e9ce20f963b4cca5da565605.jpg"
  "https://cdn2.steamgriddb.com/hero/ecd812da02543c0269cfc2c56ab3c3c0.png"
  "https://cdn2.steamgriddb.com/logo/90915208c601cc8c86ad01250ee90c12.png"
  "https://cdn2.steamgriddb.com/icon/add7a048049671970976f3e18f21ade3.ico"
)

# Find Steam userdata directory
USERDATA="$HOME/.steam/steam/userdata"
USER_ID=$(ls "$USERDATA" | grep -E '^[0-9]+$' | head -n1)
if [ -z "$USER_ID" ]; then
  echo "❌ No Steam user found."
  exit 1
fi
CONFIG_DIR="$USERDATA/$USER_ID/config"
SHORTCUTS_FILE="$CONFIG_DIR/shortcuts.vdf"
GRID_DIR="$CONFIG_DIR/grid"
mkdir -p "$GRID_DIR"

# Generate appid (same as in the python script)
CRC32_HEX=$(echo -n "$APPNAME$EXE" | cksum -o3 | awk '{print $1}')
APPID=$((0x80000000 | 0x$CRC32_HEX))

# Add shortcut if not already present
if grep -q "$EXE" "$SHORTCUTS_FILE" 2>/dev/null; then
  echo "✅ Shortcut already exists."
else
  # Insert new shortcut before last two \x08s
  # This is a minimal VDF binary append (not robust for all edge cases)
  echo "[INFO] Adding shortcut to $SHORTCUTS_FILE (binary append)"
  # Backup
  cp "$SHORTCUTS_FILE" "$SHORTCUTS_FILE.bak.$(date +%s)"
  # Use python for binary append (safer)
  python3 - "$SHORTCUTS_FILE" "$APPNAME" "$EXE" "$STARTDIR" "$APPID" <<'EOF'
import sys, struct
f = open(sys.argv[1], 'rb')
data = f.read(); f.close()
appname, exe, startdir, appid = sys.argv[2:6]
appid = int(appid)
def make_entry(idx, appid, appname, exe, startdir):
    x00 = b'\x00'; x01 = b'\x01'; x02 = b'\x02'; x08 = b'\x08'
    b = b''
    b += x00 + str(idx).encode() + x00
    b += x02 + b'appid' + x00 + struct.pack('<I', appid)
    b += x01 + b'appname' + x00 + appname.encode() + x00
    b += x01 + b'exe' + x00 + exe.encode() + x00
    b += x01 + b'StartDir' + x00 + startdir.encode() + x00
    b += x01 + b'icon' + x00 + b'' + x00
    b += x08
    return b
idx = 0
while (b'\x00'+str(idx).encode()+b'\x00') in data: idx += 1
entry = make_entry(idx, appid, appname, exe, startdir)
if data.endswith(b'\x08\x08'):
    newdata = data[:-2] + entry + b'\x08\x08'
    with open(sys.argv[1], 'wb') as f: f.write(newdata)
    print(f"✅ Minecraft shortcut added with index {idx} and appid {appid}")
else:
    print("❌ File structure not recognized. No changes made.")
    sys.exit(1)
EOF
fi

# Download SteamGridDB artwork
for url in "${STEAMGRIDDB_IMAGES[@]}"; do
  fname="$GRID_DIR/${APPID}_$(basename "$url")"
  if [ -f "$fname" ]; then
    echo "✅ Skipping artwork: $fname already exists."
    continue
  fi
  echo "Downloading: $url"
  curl -L "$url" -o "$fname"
done

echo "✅ All done. Launch Steam to see Minecraft in your Library."
