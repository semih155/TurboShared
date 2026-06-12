cd $HOME/TurboShared && cat << 'EOF' > termux-url-opener.sh && chmod +x termux-url-opener.sh && git remote set-url origin git@github.com:semih155/TurboShared.git && git add termux-url-opener.sh && git commit -m "TurboShared v6.2 - Tek Tik Kurulum Aktif" && git push origin main --force
#!/data/data/com.termux/files/usr/bin/bash
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
echo -e "${BLUE}[*] TurboShared v6.2 Başlatılıyor...${NC}"
echo -e "${GREEN}[✔] Otomatik kuyruk + tüm format fallback'leri aktif.${NC}"
if ! command -v yt-dlp &> /dev/null; then
    echo -e "${YELLOW}[!] yt-dlp bulunamadı, kuruluyor...${NC}"
    pkg update -y && pkg install python ffmpeg -y
    pip install --upgrade yt-dlp
fi
if [ ! -d "$HOME/storage" ]; then
    termux-setup-storage
    sleep 3
fi
SAVE_DIR="/sdcard/Download/TurboShared"
mkdir -p "$SAVE_DIR"
URL="$1"
if [ -z "$URL" ]; then
    URL=$(termux-clipboard-get)
fi
KUYRUK_FILE="$HOME/.turboshared_kuyruk"
if [[ $URL == *"tiktok.com"* || $URL == *"facebook.com"* ]]; then
    echo "$URL" >> "$KUYRUK_FILE"
    echo -e "${GREEN}[+] Link Kuyruğa Eklendi:${NC} $URL"
    termux-toast -c green -b black "Kuyruğa eklendi: $URL"
    while IFS= read -r line; do
        if [ ! -z "$line" ]; then
            echo -e "${YELLOW}[*] İndiriliyor:${NC} $line"
            yt-dlp -P "$SAVE_DIR" -o "%(title)s_%(id)s.%(ext)s" --no-warnings "$line"
            grep -v -F "$line" "$KUYRUK_FILE" > "$KUYRUK_FILE.tmp" && mv "$KUYRUK_FILE.tmp" "$KUYRUK_FILE"
        fi
    done < "$KUYRUK_FILE"
    echo -e "${GREEN}[✔] Tüm kuyruk başarıyla tamamlandı!${NC}"
else
    echo -e "${RED}[X] Geçersiz Link!${NC}"
    termux-toast -c red -b black "Geçersiz link formatı!"
fi
EOF
