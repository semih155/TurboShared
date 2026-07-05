cat > ~/bin/termux-url-opener << 'EOF'
#!/bin/bash

KUYRUK_FILE="$HOME/.turbo_kuyruk"
KILIT_FILE="$HOME/.turbo_kilit"
LOG_FILE="$HOME/.turbo_hatalar"
CANLI_LOG="$HOME/.turbo_canli_log"
BASE_DIR="/storage/emulated/0/Download/TurboShared"
mkdir -p "$BASE_DIR"

bildir() {
    command -v termux-toast >/dev/null 2>&1 && termux-toast "$1"
}

url=$(echo "$1" | grep -oP 'https?://[^\s]+' | head -1)
[[ -z "$url" ]] && exit 1

kilit_gecerli_mi() {
    [[ ! -f "$KILIT_FILE" ]] && return 1
    local satir pid zaman simdi fark
    satir=$(cat "$KILIT_FILE")
    pid=$(echo "$satir" | cut -d'|' -f1)
    zaman=$(echo "$satir" | cut -d'|' -f2)
    simdi=$(date +%s)
    [[ -z "$zaman" ]] && return 1
    fark=$((simdi - zaman))
    [ $fark -gt 600 ] && return 1
    kill -0 "$pid" 2>/dev/null && return 0
    return 1
}

if [[ $url == *"tiktok.com/@"* ]] && [[ $url != *"/video/"* ]] && [[ $url != *"/photo/"* ]]; then
    echo "📌 TikTok profili tespit edildi!"
    read -p "📥 Kaç video indirilsin? (Hepsi için 0): " adet
    [[ -z "$adet" ]] && adet=10
    echo "${url}|||${adet}" >> "$KUYRUK_FILE"
else
    echo "$url" >> "$KUYRUK_FILE"
fi

echo ""
echo "========================================"
echo "  TurboShared v9.6"
echo "========================================"

if kilit_gecerli_mi; then
    echo "  Zaten indirme surüyor, kuyruğa eklendi"
    echo "  Sıradaki video: $(wc -l < "$KUYRUK_FILE") link bekliyor"
    echo "========================================"
    echo ""
    echo "--- CANLI INDIRME DURUMU ---"
    echo "(Çıkmak için CTRL+C)"
    echo ""
    # Canlı log takibi — worker ne yapıyorsa göster
    tail -f "$CANLI_LOG" 2>/dev/null &
    TAIL_PID=$!
    # Worker bitince tail'i de kapat
    while kilit_gecerli_mi; do
        sleep 2
    done
    kill "$TAIL_PID" 2>/dev/null
    echo ""
    echo "========================================"
    echo "  Tum indirmeler tamamlandi!"
    echo "========================================"
else
    rm -f "$KILIT_FILE"
    echo "  Indirme basliyor..."
    echo "========================================"
    echo ""
    # Worker'ı başlat, çıktısını hem ekrana hem log dosyasına yaz
    bash "$HOME/bin/turbo-worker.sh" 2>&1 | tee "$CANLI_LOG"
fi
EOF
chmod +x ~/bin/termux-url-opener

cat > ~/bin/turbo-worker.sh << 'EOF'
#!/bin/bash

KUYRUK_FILE="$HOME/.turbo_kuyruk"
KILIT_FILE="$HOME/.turbo_kilit"
LOG_FILE="$HOME/.turbo_hatalar"
BASE_DIR="/storage/emulated/0/Download/TurboShared"
MUZIK_DIR="/storage/emulated/0/Download/TurboShared/Muzik"
mkdir -p "$BASE_DIR" "$MUZIK_DIR"

bildir() {
    command -v termux-toast >/dev/null 2>&1 && termux-toast "$1"
}

kilit_guncelle() {
    echo "$$|$(date +%s)" > "$KILIT_FILE"
}

kilit_guncelle
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

( while true; do sleep 60; [[ -f "$KILIT_FILE" ]] && kilit_guncelle; done ) &
TAZELEYICI_PID=$!

temizlik() {
    kill "$TAZELEYICI_PID" 2>/dev/null
    rm -f "$KILIT_FILE"
    command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock
}
trap temizlik EXIT

is_tiktok() { [[ $1 == *"tiktok.com"* ]] || [[ $1 == *"vm.tiktok.com"* ]] || [[ $1 == *"vt.tiktok.com"* ]]; }
is_facebook() { [[ $1 == *"facebook.com"* ]] || [[ $1 == *"fb.watch"* ]] || [[ $1 == *"fb.com"* ]]; }

ag_bekle() {
    local deneme=0
    echo "Ag baglantisi kontrol ediliyor..."
    while [ $deneme -lt 10 ]; do
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            return 0
        fi
        deneme=$((deneme + 1))
        echo "Ag yok, 3 saniye sonra tekrar... ($deneme/10)"
        sleep 3
    done
    return 1
}

progress_bar() {
    local pct="$1"
    local eta="$2"
    local width=25
    local dolu=$((pct * width / 100))
    local bos=$((width - dolu))
    local bar=""
    local i
    for ((i=0; i<dolu; i++)); do bar+="#"; done
    for ((i=0; i<bos; i++)); do bar+="-"; done
    printf "\r  [%s] %3d%%  ETA: %s   " "$bar" "$pct" "$eta"
}

yt_dlp_ilerlemeli() {
    yt-dlp --newline "$@" 2>&1 | while IFS= read -r line; do
        if [[ $line =~ \[download\][[:space:]]+([0-9]+)\.[0-9]%.*ETA[[:space:]]+([0-9:]+) ]]; then
            progress_bar "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        elif [[ $line == *"[download] 100%"* ]]; then
            progress_bar 100 "00:00"
            echo ""
        elif [[ $line == *"Merging formats"* ]]; then
            echo ""
            echo "  Ses ve goruntu birlestiriliyor..."
        elif [[ $line == *"ERROR"* ]]; then
            echo ""
            echo "  UYARI: $line"
        fi
    done
    return ${PIPESTATUS[0]}
}

indir_muzik() {
    local u="$1"
    echo ""
    echo "  Fotograf/slayt post! Muzik olarak indiriliyor..."
    yt-dlp \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --no-check-certificates \
        --no-playlist \
        -x \
        --audio-format mp3 \
        --audio-quality 0 \
        -o "$MUZIK_DIR/%(title).50s [%(id)s].%(ext)s" \
        "$u"

    if [ $? -eq 0 ]; then
        echo ""
        echo "  Muzik indirildi! -> TurboShared/Muzik/"
        bildir "Muzik indirildi! TurboShared/Muzik/"
        return 0
    else
        echo "  Muzik de indirilemedi."
        return 1
    fi
}

indir_tiktok() {
    local u="$1"
    local out="$BASE_DIR/%(title).50s [%(id)s].%(ext)s"
    local extra="$2"
    local cikti

    echo "  Format 1 (kaliteli -0 varyanti)"
    cikti=$(yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --socket-timeout 15 \
        --no-check-certificates \
        --no-playlist \
        --merge-output-format mp4 \
        -f "best[vcodec^=h264][format_id*=-0]/best[format_id*=-0]" \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u" 2>&1)
    local kod=$?
    echo "$cikti"
    echo "$cikti" | grep -q "Unsupported URL.*photo" && { indir_muzik "$u"; return $?; }
    [ $kod -eq 0 ] && return 0

    echo ""
    echo "  Format 2 (-1 haric)"
    cikti=$(yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --socket-timeout 15 \
        --no-check-certificates \
        --no-playlist \
        --audio-multistreams \
        -f "bestvideo[format_id!*=-1]+bestaudio[format_id!*=-1]/best[format_id!*=-1]" \
        --merge-output-format mp4 \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u" 2>&1)
    kod=$?
    echo "$cikti"
    echo "$cikti" | grep -q "Unsupported URL.*photo" && { indir_muzik "$u"; return $?; }
    [ $kod -eq 0 ] && return 0

    echo ""
    echo "  Format 3 (son care)"
    cikti=$(yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --socket-timeout 15 \
        --no-check-certificates \
        --no-playlist \
        -f "best[ext=mp4]/best" \
        --recode-video mp4 \
        --postprocessor-args "ffmpeg:-c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u" 2>&1)
    kod=$?
    echo "$cikti"
    echo "$cikti" | grep -q "Unsupported URL.*photo" && { indir_muzik "$u"; return $?; }
    return $kod
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
    echo "  Format 2 deneniyor"
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
    local tarih=$(date +%Y-%m-%d)
    local out="$BASE_DIR/$tarih/%(title).50s [%(id)s].%(ext)s"

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

indir_dene() {
    local fonksiyon="$1"
    local u="$2"
    local extra="$3"
    local tekrar=0
    local max_tekrar=2

    while [ $tekrar -le $max_tekrar ]; do
        if [ $tekrar -gt 0 ]; then
            echo ""
            echo "  >> Tekrar deneme $tekrar/$max_tekrar"
            ag_bekle
        fi

        kilit_guncelle
        "$fonksiyon" "$u" "$extra"
        [ $? -eq 0 ] && return 0

        if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            echo "  Ag kopmus, bekleniyor..."
            ag_bekle
        else
            sleep 2
        fi

        tekrar=$((tekrar + 1))
    done
    return 1
}

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
    echo "  TurboShared v9.6"
    echo "  $url"
    echo "========================================"

    local basarili=1

    if [[ -n "$adet" ]]; then
        echo "  Profil modu - $adet video"
        indir_dene indir_profil "$url" "$adet" && basarili=0
    elif is_tiktok "$url"; then
        echo "  TikTok"
        indir_dene indir_tiktok "$url" "" && basarili=0
    elif is_facebook "$url"; then
        echo "  Facebook"
        indir_dene indir_facebook "$url" "" && basarili=0
    else
        echo "  Genel"
        indir_dene indir_genel "$url" "" && basarili=0
    fi

    if [ $basarili -eq 0 ]; then
        echo ""
        echo "  Tamamlandi!"
        bildir "Indirildi"
        return 0
    else
        echo ""
        echo "  Hata! Link kaydediliyor."
        bildir "Hata, link loglandi"
        echo "$satir" >> "$LOG_FILE"
        return 1
    fi
}

while true; do
    satir=$(head -1 "$KUYRUK_FILE" 2>/dev/null)
    [[ -z "$satir" ]] && break
    link_isle "$satir"
    tail -n +2 "$KUYRUK_FILE" > "$KUYRUK_FILE.tmp" && mv "$KUYRUK_FILE.tmp" "$KUYRUK_FILE"
done

if [[ -f "$LOG_FILE" ]] && [[ -s "$LOG_FILE" ]]; then
    echo ""
    echo "========================================"
    echo "  Hatali linkler tekrar deneniyor..."
    echo "========================================"
    cp "$LOG_FILE" "$LOG_FILE.tekrar"
    > "$LOG_FILE"
    while IFS= read -r hatali_satir; do
        [[ -z "$hatali_satir" ]] && continue
        ag_bekle
        link_isle "$hatali_satir"
    done < "$LOG_FILE.tekrar"
    rm -f "$LOG_FILE.tekrar"
fi

echo ""
echo "========================================"
echo "  Tum indirmeler tamamlandi!"
echo "  Klasor: $BASE_DIR/"
echo "========================================"
if [[ -s "$LOG_FILE" ]]; then
    bildir "Tamamlandi, bazi videolar basarisiz"
else
    bildir "Tum indirmeler tamamlandi!"
fi
EOF
chmod +x ~/bin/turbo-worker.sh

rm -f ~/.turbo_kilit
echo -e "\e[1;32mv9.6 hazir! Artik indirme aninda canli goruluyor.\e[0m"
