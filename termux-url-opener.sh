cat > ~/bin/termux-url-opener << 'EOF'
#!/bin/bash

KUYRUK_FILE="$HOME/.turbo_kuyruk"
KILIT_FILE="$HOME/.turbo_kilit"
LOG_FILE="$HOME/.turbo_hatalar"
BASE_DIR="/storage/emulated/0/Download/TurboShared"
mkdir -p "$BASE_DIR"

bildir() {
    command -v termux-toast >/dev/null 2>&1 && termux-toast "$1"
}

url=$(echo "$1" | grep -oP 'https?://[^\s]+' | head -1)
[[ -z "$url" ]] && exit 1

if [[ $url == *"tiktok.com/@"* ]] && [[ $url != *"/video/"* ]]; then
    echo "📌 TikTok profili tespit edildi!"
    read -p "📥 Kaç video indirilsin? (Hepsi için 0): " adet
    [[ -z "$adet" ]] && adet=10
    echo "${url}|||${adet}" >> "$KUYRUK_FILE"
else
    echo "$url" >> "$KUYRUK_FILE"
fi

bildir "Kuyruga eklendi: $(echo $url | cut -c1-40)..."

if [[ -f "$KILIT_FILE" ]]; then
    eski_pid=$(cat "$KILIT_FILE")
    if ! kill -0 "$eski_pid" 2>/dev/null; then
        rm -f "$KILIT_FILE"
    fi
fi

[[ -f "$KILIT_FILE" ]] && exit 0

bash "$HOME/bin/turbo-worker.sh"
EOF
chmod +x ~/bin/termux-url-opener

cat > ~/bin/turbo-worker.sh << 'EOF'
#!/bin/bash

KUYRUK_FILE="$HOME/.turbo_kuyruk"
KILIT_FILE="$HOME/.turbo_kilit"
LOG_FILE="$HOME/.turbo_hatalar"
BASE_DIR="/storage/emulated/0/Download/TurboShared"
mkdir -p "$BASE_DIR"

bildir() {
    command -v termux-toast >/dev/null 2>&1 && termux-toast "$1"
}

echo $$ > "$KILIT_FILE"
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

is_tiktok() { [[ $1 == *"tiktok.com"* ]] || [[ $1 == *"vm.tiktok.com"* ]] || [[ $1 == *"vt.tiktok.com"* ]]; }
is_facebook() { [[ $1 == *"facebook.com"* ]] || [[ $1 == *"fb.watch"* ]] || [[ $1 == *"fb.com"* ]]; }

# ─────────────────────────────────────────────
# AĞ KONTROLÜ - VPN değişimi/DNS kopması bekleme
# ─────────────────────────────────────────────
ag_bekle() {
    local deneme=0
    echo "Ag baglantisi kontrol ediliyor..."
    while [ $deneme -lt 10 ]; do
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            return 0
        fi
        deneme=$((deneme + 1))
        echo "Ag yok, 3 saniye sonra tekrar denenecek... ($deneme/10)"
        sleep 3
    done
    return 1
}

# ─────────────────────────────────────────────
# İLERLEME GÖSTERİMİ (ASCII)
# ─────────────────────────────────────────────
progress_bar() {
    local pct="$1"
    local width=25
    local dolu=$((pct * width / 100))
    local bos=$((width - dolu))
    local bar=""
    local i
    for ((i=0; i<dolu; i++)); do bar+="#"; done
    for ((i=0; i<bos; i++)); do bar+="-"; done
    printf "\r[%s] %3d%%" "$bar" "$pct"
}

yt_dlp_ilerlemeli() {
    yt-dlp --newline "$@" 2>&1 | while IFS= read -r line; do
        if [[ $line =~ \[download\][[:space:]]+([0-9]+)\.[0-9]%.*ETA[[:space:]]+([0-9:]+) ]]; then
            progress_bar "${BASH_REMATCH[1]}"
            printf "  ETA %s   " "${BASH_REMATCH[2]}"
        elif [[ $line == *"[download] 100%"* ]]; then
            progress_bar 100
            echo ""
        elif [[ $line == *"Merging formats"* ]]; then
            echo ""
            echo "Ses ve goruntu birlestiriliyor..."
        elif [[ $line == *"ERROR"* ]]; then
            echo ""
            echo "UYARI: $line"
        fi
    done
    return ${PIPESTATUS[0]}
}

# ─────────────────────────────────────────────
# TEKRAR DENEMELİ İNDİRME SARMALAYICISI
# Ağ hatası varsa bekler, 2 kez tekrar dener
# ─────────────────────────────────────────────
indir_dene() {
    local fonksiyon="$1"
    local u="$2"
    local extra="$3"
    local tekrar=0
    local max_tekrar=2

    while [ $tekrar -le $max_tekrar ]; do
        if [ $tekrar -gt 0 ]; then
            echo ""
            echo ">> Tekrar deneme $tekrar/$max_tekrar - $u"
            ag_bekle
        fi

        "$fonksiyon" "$u" "$extra"
        if [ $? -eq 0 ]; then
            return 0
        fi

        # Hata oldu, ag kopmasi mi kontrol et
        if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            echo "Ag baglantisi kopmus, bekleniyor..."
            ag_bekle
        else
            sleep 2
        fi

        tekrar=$((tekrar + 1))
    done
    return 1
}

indir_tiktok() {
    local u="$1"
    local out="$BASE_DIR/%(title).50s [%(id)s].%(ext)s"
    local extra="$2"

    echo "Format 1 (kaliteli -0 varyanti)"
    yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --socket-timeout 15 \
        --no-check-certificates \
        --merge-output-format mp4 \
        -f "best[vcodec^=h264][format_id*=-0]/best[format_id*=-0]" \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u" && return 0

    echo ""
    echo "Format 2 deneniyor (-1 haric)"
    yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --socket-timeout 15 \
        --no-check-certificates \
        --audio-multistreams \
        -f "bestvideo[format_id!*=-1]+bestaudio[format_id!*=-1]/best[format_id!*=-1]" \
        --merge-output-format mp4 \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u" && return 0

    echo ""
    echo "Format 3 (son care)"
    yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --socket-timeout 15 \
        --no-check-certificates \
        -f "best[ext=mp4]/best" \
        --recode-video mp4 \
        --postprocessor-args "ffmpeg:-c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u"
}

indir_facebook() {
    local u="$1"
    yt_dlp_ilerlemeli \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Accept-Language:tr-TR,tr;q=0.9,en;q=0.8" \
        --extractor-retries 5 \
        --socket-timeout 15 \
        --no-check-certificates \
        --no-playlist \
        --audio-multistreams \
        -f "bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" "$u" && return 0

    echo ""
    echo "Format 2 deneniyor"
    yt_dlp_ilerlemeli \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Accept-Language:tr-TR,tr;q=0.9,en;q=0.8" \
        --extractor-retries 5 \
        --socket-timeout 15 \
        --no-check-certificates \
        --no-playlist \
        -f "best[ext=mp4]/best" \
        --recode-video mp4 \
        --postprocessor-args "ffmpeg:-c:a aac -ar 44100 -ac 2" \
        -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" "$u"
}

indir_genel() {
    local u="$1"
    yt_dlp_ilerlemeli \
        --no-playlist \
        --no-check-certificates \
        --socket-timeout 15 \
        -f "bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" "$u"
}

indir_profil() {
    local u="$1"
    local adet="$2"
    local out="$BASE_DIR/%(uploader)s/%(title).50s [%(id)s].%(ext)s"

    [[ "$adet" == "0" ]] && playlist_opt="" || playlist_opt="--playlist-items 1-$adet"

    yt_dlp_ilerlemeli $playlist_opt \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --socket-timeout 15 \
        --no-check-certificates \
        --merge-output-format mp4 \
        -f "best[vcodec^=h264][format_id*=-0]/best[format_id*=-0]/best" \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u"
}

# ─────────────────────────────────────────────
# BİR LİNKİ İŞLE (normal kuyruk veya tekrar kuyruğu için ortak)
# ─────────────────────────────────────────────
link_isle() {
    local satir="$1"
    local url adet

    if [[ $satir == *"|||"* ]]; then
        url="${satir%%|||*}"
        adet="${satir##*|||}"
    else
        url="$satir"
        adet=""
    fi

    echo ""
    echo "========================================"
    echo "TurboShared v9.2"
    echo "$url"
    echo "========================================"

    local basarili=1

    if [[ -n "$adet" ]]; then
        echo "Profil indirme modu - $adet video"
        indir_dene indir_profil "$url" "$adet" && basarili=0
    elif is_tiktok "$url"; then
        echo "TikTok"
        indir_dene indir_tiktok "$url" "" && basarili=0
    elif is_facebook "$url"; then
        echo "Facebook"
        indir_dene indir_facebook "$url" "" && basarili=0
    else
        echo "Genel"
        indir_dene indir_genel "$url" "" && basarili=0
    fi

    if [ $basarili -eq 0 ]; then
        echo ""
        echo "Tamamlandi!"
        bildir "Indirildi"
        return 0
    else
        echo ""
        echo "3 denemeden sonra hala hata! Link kaydediliyor."
        bildir "Hata, link loglandi"
        echo "$satir" >> "$LOG_FILE"
        return 1
    fi
}

# ─────────────────────────────────────────────
# ANA KUYRUK DÖNGÜSÜ
# ─────────────────────────────────────────────
while true; do
    satir=$(head -1 "$KUYRUK_FILE" 2>/dev/null)
    [[ -z "$satir" ]] && break

    link_isle "$satir"

    tail -n +2 "$KUYRUK_FILE" > "$KUYRUK_FILE.tmp" && mv "$KUYRUK_FILE.tmp" "$KUYRUK_FILE"
done

# ─────────────────────────────────────────────
# KUYRUK BİTTİ - HATALI LİNKLERİ OTOMATİK TEKRAR DENE
# ─────────────────────────────────────────────
if [[ -f "$LOG_FILE" ]] && [[ -s "$LOG_FILE" ]]; then
    echo ""
    echo "========================================"
    echo "Hatali linkler tekrar deneniyor..."
    echo "========================================"

    cp "$LOG_FILE" "$LOG_FILE.tekrar"
    > "$LOG_FILE"

    while IFS= read -r hatali_satir; do
        [[ -z "$hatali_satir" ]] && continue
        echo ""
        echo ">> Hatali link tekrar deneniyor: $hatali_satir"
        ag_bekle
        link_isle "$hatali_satir"
    done < "$LOG_FILE.tekrar"

    rm -f "$LOG_FILE.tekrar"
fi

command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock
rm -f "$KILIT_FILE"
echo ""
echo "Tum indirmeler tamamlandi! Klasor: $BASE_DIR/"
if [[ -s "$LOG_FILE" ]]; then
    echo "Hala basarisiz olan linkler var: $LOG_FILE"
    bildir "Tamamlandi, bazi videolar hala basarisiz"
else
    bildir "Tum indirmeler tamamlandi!"
fi
EOF
chmod +x ~/bin/turbo-worker.sh

rm -f ~/.turbo_kilit
echo -e "\e[1;32mv9.2 hazir! Otomatik tekrar deneme + ag bekleme eklendi.\e[0m"
