#!/bin/bash


#Change this here !!!!!!!!!!!!!!!!1
WORDLIST="list.txt"
WORDLIST_RESULTS="wordlist_results.txt"
DIR_WORDLIST="dir_wordlist.txt"
DIR_RESULTS="directory_scan_results.txt"

timestamp() {
  date +"%Y%m%d-%H%M"
}

banner() {
cat << "EOF"
   _____              .__     
  /  ___|  ___   __ __|  |__  
  \___ \  / _ \ / //_/|  '_ \ 
 /_____/ \___/ \__,  | |_.__/ 
               |___/          
       Lightweight Scanner
EOF
echo ""
}

check_tools() {
  command -v ps >/dev/null || echo "[!] 'ps' command missing"
  command -v ss >/dev/null || echo "[!] 'ss' command missing"
  command -v find >/dev/null || echo "[!] 'find' command missing"
}

prompt_save() {
  local type="$1"
  local tmpfile="$2"
  local output

  echo -n "Would you like to save this $type scan? (y/n): "
  read -r save_choice
  if [[ "$save_choice" =~ ^[Yy]$ ]]; then
    echo -n "Enter filename (leave blank for auto-naming): "
    read -r output
    if [ -z "$output" ]; then
      output="scan_${type}_$(timestamp).txt"
    fi
    cp "$tmpfile" "$output"
    echo "[+] Saved successfully to '$output'"
  fi
}

system_info() {
  tmpfile=$(mktemp)
  {
    echo "===== System Info ====="
    echo "Hostname: $(hostname)"
    grep -E '^NAME=|^VERSION=' /etc/os-release 2>/dev/null
    echo "Kernel: $(uname -r)"
    echo "User: $(whoami) ($(id))"
    echo ""
  } > "$tmpfile"

  cat "$tmpfile"
  prompt_save "system" "$tmpfile"
  rm -f "$tmpfile"
}

network_info() {
  {
    echo "===== Network Info ====="
    ip a
    echo ""
    echo "Open Ports:"
    ss -tuln
    echo ""
  } | tee >(prompt_save "network")
}

package_info() {
  {
    echo "===== Installed Packages ====="
    dpkg -l 2>/dev/null | head -n 10 || rpm -qa 2>/dev/null | head -n 10
    echo ""
  } | tee >(prompt_save "packages")
}

sensitive_info() {
  {
    echo "===== Sensitive Files ====="
    echo "[+] SUID Files:"
    find / -perm -4000 -type f 2>/dev/null | head -n 10
    echo ""
    echo "[+] Writable Directories:"
    find / -writable -type d 2>/dev/null | grep -v /proc | head -n 10
    echo ""
    echo "[+] Interesting Config Files:"
    find / -type f \( -iname "*pass*" -o -iname "*config*" -o -iname "*.conf" \) 2>/dev/null | head -n 10
    echo ""
  } | tee >(prompt_save "sensitive")
}

wordlist_search() {
  local ACTIVE_WORDLIST="$WORDLIST"
  if [ ! -f "$ACTIVE_WORDLIST" ]; then
    echo "[!] '$WORDLIST' not found. Falling back to auto-generated list: auto_wordlist.txt"
    if [ ! -f "auto_wordlist.txt" ]; then
      echo "[!] 'auto_wordlist.txt' is also missing. Cannot continue."
      return 1
    fi
    ACTIVE_WORDLIST="auto_wordlist.txt"
  fi

  {
    echo "===== Wordlist-Based Search ====="
    echo "Using: $ACTIVE_WORDLIST"
    > "$WORDLIST_RESULTS"

    while IFS= read -r path; do
      [[ -z "$path" || "$path" =~ ^
      expanded_paths=$(eval echo "$path")  
      for p in $expanded_paths; do
        if [ -e "$p" ]; then
          echo "Found: $p"
          echo "$p" >> "$WORDLIST_RESULTS"
        fi
      done
    done < "$ACTIVE_WORDLIST"

    if [ -s "$WORDLIST_RESULTS" ]; then
      echo "[+] Results saved to $WORDLIST_RESULTS"
    else
      echo "[!] No files found matching the wordlist."
      rm -f "$WORDLIST_RESULTS"
    fi
  } | tee >(prompt_save "wordlist")
}


directory_scan() {
  {
    echo "===== Directory Scan ====="
    echo "Scanning full filesystem using: $DIR_WORDLIST"
    if [ ! -f "$DIR_WORDLIST" ]; then
      echo "[!] Creating default directory wordlist..."
      cat << EOF > "$DIR_WORDLIST"
admin
backup
config
logs
secrets
tmp
hidden
users
dev
test
web
EOF
    fi

    > "$DIR_RESULTS"
    while IFS= read -r dir; do
      [[ -z "$dir" || "$dir" =~ ^# ]] && continue
      matches=$(find / -type d -name "$dir" 2>/dev/null)
      if [ -n "$matches" ]; then
        echo "Matches for '$dir':"
        echo "$matches"
        echo "$matches" >> "$DIR_RESULTS"
      fi
    done < "$DIR_WORDLIST"

    if [ -s "$DIR_RESULTS" ]; then
      echo "[*] Directory scan complete. Results saved to $DIR_RESULTS"
    else
      echo "[!] No directories found matching the wordlist."
      rm -f "$DIR_RESULTS"
    fi
  } | tee >(prompt_save "directory")
}

run_all_scans() {
  echo "[*] Starting full scan..."
  read -rp "Run system info scan? (y/n): " choice
  [[ "$choice" =~ ^[Yy]$ ]] && system_info
  read -rp "Run network info scan? (y/n): " choice
  [[ "$choice" =~ ^[Yy]$ ]] && network_info
  read -rp "Run installed packages scan? (y/n): " choice
  [[ "$choice" =~ ^[Yy]$ ]] && package_info
  read -rp "Run sensitive file scan? (y/n): " choice
  [[ "$choice" =~ ^[Yy]$ ]] && sensitive_info

  echo "[*] Full scan complete."
}




show_menu() {
  while true; do
    echo ""
    echo "==== Main Menu ===="
    echo "1) Full Scan (System, Network, Packages, Sensitive Files)"
    echo "2) Wordlist-based File Search"
    echo "3) Directory Scan using Wordlist"
    echo "4) System Info Only"
    echo "5) Network Info Only"
    echo "6) Installed Packages Only"
    echo "7) Sensitive File Checks Only"
    echo "8) Exit"
    read -rp "Choose an option: " choice

    case $choice in
      1) run_all_scans ;;
      2) wordlist_search ;;
      3) directory_scan ;;
      4) system_info ;;
      5) network_info ;;
      6) package_info ;;
      7) sensitive_info ;;
      8) echo "Exiting..."; exit 0 ;;
      *) echo "Invalid choice, try again." ;;
    esac
  done
}



banner
check_tools
show_menu
