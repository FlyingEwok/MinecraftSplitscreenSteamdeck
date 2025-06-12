#!/usr/bin/env python3
# --- Minecraft Splitscreen Steam Shortcut Adder ---
# This script adds a custom Minecraft Splitscreen launcher to Steam's shortcuts.vdf,
# and downloads SteamGridDB artwork for a polished look in your Steam library.
# It is designed to work for any Linux user (not just Steam Deck).
#
# Based on the original script by ArnoldSmith86:
# https://github.com/ArnoldSmith86/minecraft-splitscreen
# Modified and improved for portability and clarity.

import os
import re
import struct
import zlib
import urllib.request

# --- Config: Set up paths and app info dynamically for the current user ---
HOME = os.path.expanduser("~")  # Get the current user's home directory
APPNAME  = "Minecraft Splitscreen"  # Name as it will appear in Steam
EXE      = f'{HOME}/.local/share/PollyMC/minecraft.sh'  # Path to the launch script
STARTDIR = f"{HOME}/.local/share/PollyMC"  # Working directory for the shortcut

# SteamGridDB artwork URLs for custom grid images, hero, logo, and icon
STEAMGRIDDB_IMAGES = {
    "p": "https://cdn2.steamgriddb.com/grid/a73027901f88055aaa0fd1a9e25d36c7.png",  # Portrait grid
    "": "https://cdn2.steamgriddb.com/grid/e353b610e9ce20f963b4cca5da565605.jpg",      # Main grid
    "_hero": "https://cdn2.steamgriddb.com/hero/ecd812da02543c0269cfc2c56ab3c3c0.png", # Hero image
    "_logo": "https://cdn2.steamgriddb.com/logo/90915208c601cc8c86ad01250ee90c12.png", # Logo
    "_icon": "https://cdn2.steamgriddb.com/icon/add7a048049671970976f3e18f21ade3.ico"   # Icon
}

# --- Locate Steam shortcuts file for the current user ---
userdata = os.path.expanduser("~/.steam/steam/userdata")  # Steam userdata directory
user_id = next((d for d in os.listdir(userdata) if d.isdigit()), None)  # Find the first numeric user ID
if not user_id:
    print("❌ No Steam user found.")
    exit(1)
config_dir = os.path.join(userdata, user_id, "config")  # Path to config directory
shortcuts_file = os.path.join(config_dir, "shortcuts.vdf")  # Path to shortcuts.vdf

# --- Ensure shortcuts.vdf exists (create if missing) ---
if not os.path.exists(shortcuts_file):
    with open(shortcuts_file, "wb") as f:
        f.write(b'\x00shortcuts\x00\x08\x08')  # Write empty VDF structure

# --- Read current shortcuts.vdf into memory ---
with open(shortcuts_file, "rb") as f:
    data = f.read()

def get_latest_index(data):
    """
    Find the highest shortcut index in the VDF file.
    Steam shortcuts are stored as binary blobs with indices: \x00<index>\x00
    """
    matches = re.findall(rb'\x00(\d+)\x00', data)
    if matches:
        return int(matches[-1])
    return -1

# --- Determine the next shortcut index ---
index = get_latest_index(data) + 1

# --- Helper: Create a binary shortcut entry for Steam's VDF format ---
def make_entry(index, appid, appname, exe, startdir):
    """
    Build a binary VDF entry for a Steam shortcut.
    Args:
        index (int): Shortcut index
        appid (int): Unique app ID
        appname (str): Name in Steam
        exe (str): Executable path
        startdir (str): Working directory
    Returns:
        bytes: Binary VDF entry
    """
    x00 = b'\x00'; x01 = b'\x01'; x02 = b'\x02'; x08 = b'\x08'
    b = b''
    b += x00 + str(index).encode() + x00  # Shortcut index
    b += x02 + b'appid' + x00 + struct.pack('<I', appid)  # AppID
    b += x01 + b'appname' + x00 + appname.encode() + x00  # App name
    b += x01 + b'exe' + x00 + exe.encode() + x00          # Executable
    b += x01 + b'StartDir' + x00 + startdir.encode() + x00  # Working dir
    b += x01 + b'icon' + x00 + config_dir.encode() + b'/grid/' + str(appid).encode() + b'_icon.ico' + x00  # Icon path
    b += x08  # End of entry
    return b

# --- Generate a unique appid for the shortcut (matches Steam's logic) ---
appid = 0x80000000 | zlib.crc32((APPNAME + EXE).encode("utf-8")) & 0xFFFFFFFF
entry = make_entry(index, appid, APPNAME, EXE, STARTDIR)

# --- Insert the new shortcut entry before the last two \x08 bytes (end of VDF) ---
if data.endswith(b'\x08\x08'):
    new_data = data[:-2] + entry + b'\x08\x08'
    with open(shortcuts_file, "wb") as f:
        f.write(new_data)
    print(f"✅ Minecraft shortcut added with index {index} and appid {appid}")
else:
    print("❌ File structure not recognized. No changes made.")
    exit(1)

# --- Download SteamGridDB artwork for the new shortcut ---
grid_dir = os.path.join(userdata, user_id, "config", "grid")  # Path to grid images
os.makedirs(grid_dir, exist_ok=True)  # Ensure grid directory exists

for suffix, url in STEAMGRIDDB_IMAGES.items():
    # Determine file extension based on URL
    path = os.path.join(grid_dir, f"{appid}{suffix}.png" if not url.endswith(".ico") else f"{appid}{suffix}.ico")
    if os.path.exists(path):
        print(f"✅ Skipping {suffix} image — already exists.")
        continue
    try:
        print(f"Downloading: {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as resp, open(path, "wb") as out:
            out.write(resp.read())
        print(f"✅ Saved {suffix} image.")
    except Exception as e:
        print(f"⚠️ Failed to download {suffix} image: {e}")

print("✅ All done. Launch Steam to see Minecraft in your Library.")
