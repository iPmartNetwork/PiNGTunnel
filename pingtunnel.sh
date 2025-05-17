#!/bin/bash

# Advanced WireGuard + PiNGTunnel Menu Script 🎨
# Author: iPmart | https://github.com/iPmartNetwork/pingtunnel

NC='\033[0m'
LBLUE='\033[1;36m'
LGREEN='\033[1;32m'
LYELLOW='\033[1;33m'
LRED='\033[1;31m'
LPURPLE='\033[1;35m'
LCYAN='\033[1;96m'
WHITE='\033[1;37m'
BOLD='\033[1m'
GRAY='\033[1;30m'

EMOJI_CORE="💎"
EMOJI_TUNNEL="🌐"
EMOJI_INSTALL="⬇️"
EMOJI_REMOVE="❌"
EMOJI_UPDATE="🔄"
EMOJI_OK="✅"
EMOJI_SVC="🔄"
EMOJI_IRAN="🇮🇷"
EMOJI_KHAREJ="🌍"
EMOJI_DELETE="🗑️"
EMOJI_RESTART="🔁"
EMOJI_BACK="🔙"
EMOJI_INPUT="✏️"
EMOJI_PORT="🔌"
EMOJI_IP="🌐"
EMOJI_CONFETTI="🎉"
EMOJI_UNZIP="📦"
EMOJI_WARN="⚠️"
EMOJI_RUNNING="🟢"
EMOJI_STOP="🔴"
EMOJI_NONE="⚪"

PINGTUNNEL_BIN="/usr/local/bin/pingtunnel"
SVC_FILE="/etc/systemd/system/pingtunnel.service"
RELEASE_URL="https://github.com/iPmartNetwork/pingtunnel/releases/latest"

# ---------- Status UI Functions ----------
# Check pingtunnel version
core_status() {
  if [[ -f "$PINGTUNNEL_BIN" ]]; then
    VERSION=$("$PINGTUNNEL_BIN" -v 2>/dev/null | head -n1)
    if [[ -z "$VERSION" ]]; then
      VERSION="Unknown"
    fi
    echo -e "${LGREEN}${EMOJI_OK} PiNGTunnel Installed${NC}"
    echo -e "${LBLUE}   Version: ${LYELLOW}$VERSION${NC}"
  else
    echo -e "${LRED}${EMOJI_REMOVE} PiNGTunnel Not Installed${NC}"
  fi
}

# Check service and tunnel status
tunnel_status() {
  if [[ ! -f "$SVC_FILE" ]]; then
    echo -e "${GRAY}${EMOJI_NONE} Tunnel Service Not Configured${NC}"
    return
  fi
  systemctl is-active --quiet pingtunnel
  if [[ $? -eq 0 ]]; then
    STATUS="${LGREEN}${EMOJI_RUNNING} Running${NC}"
  else
    STATUS="${LRED}${EMOJI_STOP} Stopped${NC}"
  fi

  # Try to guess tunnel type & port from systemd file
  local TYPE=""
  local PORT=""
  local REMOTE=""
  CMD=$(grep '^ExecStart=' "$SVC_FILE" | sed 's/ExecStart=//')
  if echo "$CMD" | grep -q " -type s "; then
    TYPE="${EMOJI_KHAREJ} KHAREJ"
    PORT=$(echo "$CMD" | grep -o '\-l :[0-9]*' | cut -d: -f2)
    [[ -z "$PORT" ]] && PORT="?"
    REMOTE=$(echo "$CMD" | grep -o '\-r [^ ]*' | awk '{print $2}')
    [[ -z "$REMOTE" ]] && REMOTE="?"
    echo -e "${LCYAN}${TYPE}${NC} ${EMOJI_PORT} Port: ${LYELLOW}${PORT}${NC} ${EMOJI_RUNNING} $STATUS"
  elif echo "$CMD" | grep -q " -type c "; then
    TYPE="${EMOJI_IRAN} Iran"
    PORT=$(echo "$CMD" | grep -o '\-l 127.0.0.1:[0-9]*' | cut -d: -f3)
    [[ -z "$PORT" ]] && PORT="?"
    REMOTE=$(echo "$CMD" | grep -o '\-s [^ ]*' | awk '{print $2}')
    [[ -z "$REMOTE" ]] && REMOTE="?"
    echo -e "${LPURPLE}${TYPE}${NC} ${EMOJI_PORT} Port: ${LYELLOW}${PORT}${NC} ${EMOJI_RUNNING} $STATUS"
    echo -e "${LCYAN}  → Connects to KHAREJ: ${LYELLOW}${REMOTE}${NC}"
  else
    echo -e "${GRAY}${EMOJI_NONE} Tunnel Service Configured (Unknown Type) $STATUS${NC}"
  fi
}
# ---------- End UI Functions ----------

# Detect architecture for file selection
get_arch_file() {
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  echo "pingtunnel_linux_amd64.zip";;
    aarch64) echo "pingtunnel_linux_arm64.zip";;
    armv7l)  echo "pingtunnel_linux_arm.zip";;
    *) echo ""; return 1;;
  esac
}

install_core() {
  ZIP_FILE=$(get_arch_file)
  if [[ -z "$ZIP_FILE" ]]; then
    echo -e "${LRED}Unsupported architecture!${NC}"
    return 1
  fi

  TMP_DIR=$(mktemp -d)
  echo -e "${LCYAN}${EMOJI_INSTALL} Downloading PiNGTunnel core for your architecture...${NC}"
  # Fetch direct download link using GitHub API
  API_URL="https://api.github.com/repos/iPmartNetwork/pingtunnel/releases/latest"
  DL_URL=$(curl -s $API_URL | grep "browser_download_url" | grep "$ZIP_FILE" | head -n1 | cut -d '"' -f 4)

  if [[ -z "$DL_URL" ]]; then
    echo -e "${LRED}${EMOJI_REMOVE} Download link not found for $ZIP_FILE!${NC}"
    rm -rf "$TMP_DIR"
    return 1
  fi

  curl -L --output "$TMP_DIR/$ZIP_FILE" "$DL_URL"
  if [[ $? -ne 0 ]]; then
    echo -e "${LRED}${EMOJI_REMOVE} Download failed!${NC}"
    rm -rf "$TMP_DIR"
    return 1
  fi

  echo -e "${LYELLOW}${EMOJI_UNZIP} Unzipping...${NC}"
  apt-get update >/dev/null 2>&1
  apt-get install -y unzip >/dev/null 2>&1
  unzip -o "$TMP_DIR/$ZIP_FILE" -d "$TMP_DIR" >/dev/null
  if [[ ! -f "$TMP_DIR/pingtunnel" ]]; then
    echo -e "${LRED}Unzip failed or pingtunnel binary not found!${NC}"
    rm -rf "$TMP_DIR"
    return 1
  fi

  mv "$TMP_DIR/pingtunnel" "$PINGTUNNEL_BIN"
  chmod +x "$PINGTUNNEL_BIN"
  rm -rf "$TMP_DIR"
  echo -e "${LGREEN}${EMOJI_OK} PiNGTunnel installed successfully!${NC}"
}

remove_core() {
  if [[ -f "$PINGTUNNEL_BIN" ]]; then
    rm -f "$PINGTUNNEL_BIN"
    echo -e "${LRED}${EMOJI_REMOVE} PiNGTunnel removed.${NC}"
  else
    echo -e "${LYELLOW}PiNGTunnel not found.${NC}"
  fi
}

update_core() {
  remove_core
  install_core
  echo -e "${LGREEN}${EMOJI_UPDATE} PiNGTunnel updated!${NC}"
}

create_service() {
  cat > "$SVC_FILE" <<EOF
[Unit]
Description=PiNGTunnel Service
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=$1

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable pingtunnel
  systemctl restart pingtunnel
}

remove_service() {
  systemctl stop pingtunnel 2>/dev/null
  systemctl disable pingtunnel 2>/dev/null
  rm -f "$SVC_FILE"
  systemctl daemon-reload
  echo -e "${LRED}${EMOJI_DELETE} Tunnel service removed.${NC}"
}

restart_service() {
  systemctl restart pingtunnel
  echo -e "${LGREEN}${EMOJI_RESTART} Tunnel service restarted.${NC}"
}

setup_KHAREJ_tunnel() {
  read -p "$(echo -e ${EMOJI_PORT}${BOLD} Enter tunnel port [Default: 443]:${NC} ) " TUNNEL_PORT
  TUNNEL_PORT=${TUNNEL_PORT:-443}
  read -p "$(echo -e ${EMOJI_PORT}${BOLD} Enter WireGuard port [e.g. 51820]:${NC} ) " WG_PORT
  PT_CMD="$PINGTUNNEL_BIN -type s -l :$TUNNEL_PORT -r 127.0.0.1:$WG_PORT"
  create_service "$PT_CMD"
  echo -e "${LGREEN}${EMOJI_OK} KHAREJ tunnel is running!${NC}"
}

setup_iran_tunnel() {
  read -p "$(echo -e ${EMOJI_IP}${BOLD} Enter KHAREJ server IP:${NC} ) " SERVER_IP
  read -p "$(echo -e ${EMOJI_PORT}${BOLD} Enter tunnel port [Default: 443]:${NC} ) " TUNNEL_PORT
  TUNNEL_PORT=${TUNNEL_PORT:-443}
  read -p "$(echo -e ${EMOJI_PORT}${BOLD} Enter WireGuard port [e.g. 51820]:${NC} ) " WG_PORT
  PT_CMD="$PINGTUNNEL_BIN -type c -l 127.0.0.1:$WG_PORT -s $SERVER_IP:$TUNNEL_PORT"
  create_service "$PT_CMD"
  echo -e "${LGREEN}${EMOJI_OK} Iran tunnel is running!${NC}"
}

tunnel_menu() {
  while true; do
    echo -e "${LBLUE}${BOLD}\n==== Tunnel Manager ${EMOJI_TUNNEL} ====${NC}"
    echo -e "${LYELLOW}1) Create KHAREJ Tunnel ${EMOJI_KHAREJ}${NC}"
    echo -e "${LGREEN}2) Create Iran Tunnel ${EMOJI_IRAN}${NC}"
    echo -e "${LRED}3) Remove Tunnel ${EMOJI_DELETE}${NC}"
    echo -e "${LCYAN}4) Restart Tunnel ${EMOJI_RESTART}${NC}"
    echo -e "${LPURPLE}0) Back ${EMOJI_BACK}${NC}"
    read -p "$(echo -e ${EMOJI_INPUT}${BOLD} Choose an option:${NC} ) " opt
    case $opt in
      1) setup_KHAREJ_tunnel ;;
      2) setup_iran_tunnel ;;
      3) remove_service ;;
      4) restart_service ;;
      0) break ;;
      *) echo -e "${LRED}Invalid option.${NC}";;
    esac
  done
}

core_menu() {
  while true; do
    echo -e "${LYELLOW}${BOLD}\n==== Core Manager ${EMOJI_CORE} ====${NC}"
    echo -e "${LGREEN}1) Install PiNGTunnel ${EMOJI_INSTALL}${NC}"
    echo -e "${LRED}2) Remove PiNGTunnel ${EMOJI_REMOVE}${NC}"
    echo -e "${LCYAN}3) Update PiNGTunnel ${EMOJI_UPDATE}${NC}"
    echo -e "${LPURPLE}0) Back ${EMOJI_BACK}${NC}"
    read -p "$(echo -e ${EMOJI_INPUT}${BOLD} Choose an option:${NC} ) " opt
    case $opt in
      1) install_core ;;
      2) remove_core ;;
      3) update_core ;;
      0) break ;;
      *) echo -e "${LRED}Invalid option.${NC}";;
    esac
  done
}

show_logo() {
echo -e "${LPURPLE}${BOLD}"
echo "╔═════════════════════════════════════════════╗"
echo "║     ${EMOJI_CORE} WireGuard PiNGTunnel Panel  ${EMOJI_TUNNEL}     ║"
echo "╚═════════════════════════════════════════════╝"
echo -e "${NC}"
}

show_status_cards() {
  echo -e "${LPURPLE}${BOLD}╔═══════════════════════════╗${NC}"
  echo -e "${LPURPLE}${BOLD}║  PiNGTunnel Core Status   ║${NC}"
  echo -e "${LPURPLE}${BOLD}╚═══════════════════════════╝${NC}"
  core_status
  echo -e "${LCYAN}${BOLD}╔═════════════════════════════╗${NC}"
  echo -e "${LCYAN}${BOLD}║  Tunnel Status (IRAN/KHAREJ)║${NC}"
  echo -e "${LCYAN}${BOLD}╚═════════════════════════════╝${NC}"
  tunnel_status
  echo ""
}

while true; do
  clear
  show_logo
  show_status_cards
  echo -e "${LBLUE}${BOLD}Main Menu${NC}"
  echo -e "${LYELLOW}1) Core Manager ${EMOJI_CORE}${NC}"
  echo -e "${LGREEN}2) Tunnel Manager ${EMOJI_TUNNEL}${NC}"
  echo -e "${LRED}0) Exit ${EMOJI_CONFETTI}${NC}"
  read -p "$(echo -e ${EMOJI_INPUT}${BOLD} Choose an option:${NC} ) " opt
  case $opt in
    1) core_menu ;;
    2) tunnel_menu ;;
    0) echo -e "${LGREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${LRED}Invalid option.${NC}"; sleep 1 ;;
  esac
done
