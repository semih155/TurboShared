#!/data/data/com.termux/files/usr/bin/bash

# ========================================================
# TurboShared v7.0 - Profesyonel Otomatik İndirme Sistemi
# ========================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear
echo -e "${CYAN}==================================================${NC}"
echo -e "${MAGENTA}    🚀 TurboShared v7.0 - Otomatik İndirme Sistemi 🚀${NC}"
echo -e "${CYAN}==================================================${NC}"

# Bağımlılık Kontrolleri
if ! command -v yt-dlp &> /dev/null; then
    echo -e "${YELLOW}[!] yt-dlp bulunamadı, kuruluyor...${NC}"
    pkg update -y && pkg install python ffmpeg -y
    pip install --upgrade yt-dlp
fi

# Depolama İzni Kontrolü
if [ ! -d "$HOME/storage" ]; then
    echo -e "${YELLOW}[!] Depolama izni isteniyor, lütfen onaylayın...${NC}"
    termux-setup-storage
    sleep 4
fi

SAVE_DIR="/sdcard/Download/TurboShared"
mkdir -p "$SAVE_DIR"

# Gelen URL Kontrolü
URL="$1"
if [ -z "$URL" ]; then
    URL=$(termux-clipboard-get)
fi

if [ -z "$URL" ]; then
    echo -e "${RED}[X] Hata: Herhangi bir link algılanamadı!${NC}"
    termux-toast -c red -b black "Link bulunamadı!"
    exit 1
fi

KUYRUK_FILE="$HOME/.turboshared_kuyruk"
rm -f "$KUYRUK_FILE"

YTDLP_LIMIT=""
YTDLP_ORDER=""

# TikTok Profil Linki Filtresi
if [[ $URL == *"tiktok.com"* && $URL == *"@"* && $URL != *"/video/"* ]]; then
    echo -e "${YELLOW}[?] Bir TikTok Profil Linki Algılandı!${NC}"
    echo -e "${CYAN}--------------------------------------------------${NC}"
    
    # 1. Seçenek: Video Sayısı Limitleme
    echo -e "${BLUE}▶ Kaç adet video indirmek istersiniz?${NC}"
    echo -e "  (Sayı girin örn: 5, 10 veya hepsini indirmek için ${GREEN}tüm${NC} yazın)"
    read -p "Seçiminiz: " ADET
    if [[ "$ADET" == "tüm" || "$ADET" == "tum" || -z "$ADET" ]]; then
        YTDLP_LIMIT=""
        echo -e "${GREEN}[✔] Profildeki tüm videolar hedeflendi.${NC}"
    else
        YTDLP_LIMIT="--max-downloads $ADET"
        echo -e "${GREEN}[✔] Son $ADET video indirilecek.${NC}"
    fi
    
    # 2. Seçenek: İndirme Sıralama Yönü
    echo -e "${CYAN}--------------------------------------------------${NC}"
    echo -e "${BLUE}▶ İndirme yönü nasıl olsun?${NC}"
    echo -e "  1) En Son Yüklenenlerden Başla (Yeniden Eskiye)"
    echo -e "  2) En Başta Yüklenenlerden Başla (Eskiden Yeniye)"
    read -p "Seçiminiz (1 veya 2): " SIRALAMA
    
    if [ "$SIRALAMA" == "2" ]; then
        YTDLP_ORDER="--playlist-reverse"
        echo -e "${GREEN}[✔] Eskiden yeniye doğru sıralama aktif edildi.${NC}"
    else
        YTDLP_ORDER=""
        echo -e "${GREEN}[✔] Yeniden eskiye doğru sıralama aktif edildi.${NC}"
    fi
    echo -e "${CYAN}--------------------------------------------------${NC}"
    
    echo -e "${YELLOW}[*] Profildeki videolar taranıyor, lütfen bekleyin...${NC}"
    
    # Profil videolarını listele ve kuyruğa at
    yt-dlp --flat-playlist --get-id "$URL" 2>/dev/null | while read -r id; do
        if [ ! -z "$id" ]; then
            echo "https://www.tiktok.com/@user/video/$id" >> "$KUYRUK_FILE"
        fi
    done
fi

# Tekil video linki ise doğrudan kuyruk dosyasına yaz
if [[ ! -f "$KUYRUK_FILE" ]]; then
    echo "$URL" >> "$KUYRUK_FILE"
fi

# Ana İndirme Motoru (Şekilli Şukullu İlerleme Çubuğu İçerir)
TOTAL_VIDEOS=$(wc -l < "$KUYRUK_FILE" 2>/dev/null || echo "1")
CURRENT_INDEX=0

while IFS= read -r line; do
    if [ ! -z "$line" ]; then
        CURRENT_INDEX=$((CURRENT_INDEX + 1))
        echo -e "\n${CYAN}==================================================${NC}"
        echo -e "${MAGENTA}🎬 [GÖREV $CURRENT_INDEX / $TOTAL_VIDEOS]${NC} $line"
        echo -e "${CYAN}==================================================${NC}"
        
        # Şekilli durum çubuğu parametresi
        yt-dlp $YTDLP_LIMIT $YTDLP_ORDER \
            -P "$SAVE_DIR" \
            -o "%(title)s_%(id)s.%(ext)s" \
            --no-warnings \
            --progress-template "download:${YELLOW}▶ İlerleme: ${GREEN}%(_percent_str)s ${BLUE}➔ Hız: %(_speed_str)s ${CYAN}➔ Kalan: %(_eta_str)s${NC}" \
            "$line"
            
        # İşlenen linki kuyruktan kaldır
        grep -v -F "$line" "$KUYRUK_FILE" > "$KUYRUK_FILE.tmp" && mv "$KUYRUK_FILE.tmp" "$KUYRUK_FILE"
    fi
done < "$KUYRUK_FILE"

rm -f "$KUYRUK_FILE"
echo -e "\n${GREEN}🏆 [İŞLEM TAMAMLANDI] Videolar başarıyla depolama birimine indirildi!${NC}"
termux-toast -c green -b black "Tüm indirmeler başarıyla tamamlandı!"
