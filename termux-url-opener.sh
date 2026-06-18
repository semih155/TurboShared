cat > ~/bin/termux-url-opener << 'EOF'
#!/bin/bash

KUYRUK_FILE="$HOME/.turbo_kuyruk"
KILIT_FILE="$HOME/.turbo_kilit"
LOG_FILE="$HOME/.turbo_hatalar"
BASE_DIR="/storage/emulated/0/Download/TurboShared"
mkdir -p "$BASE_DIR"

url=$(echo "$1" | grep -oP 'https?://[^\s]+' | head -1)
[[ -z "$url" ]] && exit 1

# ─────────────────────────────────────────────
# PROFİL LİNKİ Mİ? -> ÖN PLANDA SORU SOR
# ─────────────────────────────────────────────
if [[ $url == *"tiktok.com/@"* ]] && [[ $url != *"/video/"* ]]; then
    echo "📌 TikTok profili tespit edildi!"
    read -p "📥 Kaç video indirilsin? (Hepsi için 0): " adet
    [[ -z "$adet" ]] && adet=10
    echo "${url}|||${adet}" >> "$KUYRUK_FILE"
else
    echo "$url" >> "$KUYRUK_FILE"
fi

termux-toast "📥 Kuyruğa eklendi: $(echo $url | cut -c1-40)..."

if [[ -f "$KILIT_FILE" ]]; then
    eski_pid=$(cat "$KILIT_FILE")
    if ! kill -0 "$eski_pid" 2>/dev/null; then
        rm -f "$KILIT_FILE"
    fi
fi

if [[ -f "$KILIT_FILE" ]]; then
    exit 0
fi

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

echo $$ > "$KILIT_FILE"
termux-wake-lock

is_tiktok_profil() { [[ $1 == *"tiktok.com/@"* ]] && [[ $1 != *"/video/"* ]]; }
is_tiktok() { [[ $1 == *"tiktok.com"* ]] || [[ $1 == *"vm.tiktok.com"* ]] || [[ $1 == *"vt.tiktok.com"* ]]; }
is_facebook() { [[ $1 == *"facebook.com"* ]] || [[ $1 == *"fb.watch"* ]] || [[ $1 == *"fb.com"* ]]; }

# ─────────────────────────────────────────────
# GÜZEL İLERLEME ÇUBUĞU
# ─────────────────────────────────────────────
progress_bar() {
    local pct="$1"
    local width=30
    local dolu=$((pct * width / 100))
    local bos=$((width - dolu))
    printf "\r["
    printf "%${dolu}s" | tr ' ' '█'
    printf "%${bos}s" | tr ' ' '░'
    printf "] %3d%%" "$pct"
}

yt_dlp_ilerlemeli() {
    yt-dlp --newline "$@" 2>&1 | while IFS= read -r line; do
        if [[ $line =~ \[download\][[:space:]]+([0-9]+)\.[0-9]%.*ETA[[:space:]]+([0-9:]+) ]]; then
            pct="${BASH_REMATCH[1]}"
            eta="${BASH_REMATCH[2]}"
            progress_bar "$pct"
            printf "  ETA: %s " "$eta"
        elif [[ $line == *"[download] 100%"* ]]; then
            progress_bar 100
            echo ""
        elif [[ $line == *"Merging formats"* ]]; then
            echo ""
            echo "🔄 Ses ve görüntü birleştiriliyor..."
        elif [[ $line == *"ERROR"* ]]; then
            echo ""
            echo "⚠️  $line"
        fi
    done
    return ${PIPESTATUS[0]}
}

indir_tiktok() {
    local u="$1"
    local out="$BASE_DIR/%(title).50s [%(id)s].%(ext)s"
    local extra="$2"

    echo "🎯 Format 1 (kaliteli -0 varyantı)"
    yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --no-check-certificates \
        --merge-output-format mp4 \
        -f "best[vcodec^=h264][format_id*=-0]/best[format_id*=-0]" \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u" && return 0

    echo "⚠️ Format 2 deneniyor (-1 hariç)"
    yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
        --no-check-certificates \
        --audio-multistreams \
        -f "bestvideo[format_id!*=-1]+bestaudio[format_id!*=-1]/best[format_id!*=-1]" \
        --merge-output-format mp4 \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u" && return 0

    echo "⚠️ Format 3 (son çare)"
    yt_dlp_ilerlemeli $extra \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Referer:https://www.tiktok.com/" \
        --extractor-retries 10 \
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
        --no-check-certificates \
        --no-playlist \
        --audio-multistreams \
        -f "bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" "$u" && return 0

    yt_dlp_ilerlemeli \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
        --add-header "Accept-Language:tr-TR,tr;q=0.9,en;q=0.8" \
        --extractor-retries 5 \
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
        --no-check-certificates \
        --merge-output-format mp4 \
        -f "best[vcodec^=h264][format_id*=-0]/best[format_id*=-0]/best" \
        --postprocessor-args "ffmpeg:-c:v copy -c:a aac -ar 44100 -ac 2" \
        -o "$out" "$u"
}

while true; do
    satir=$(head -1 "$KUYRUK_FILE" 2>/dev/null)
    [[ -z "$satir" ]] && break

    if [[ $satir == *"|||"* ]]; then
        url="${satir%%|||*}"
        adet="${satir##*|||}"
    else
        url="$satir"
        adet=""
    fi

    echo ""
    echo "════════════════════════════════════════"
    echo "🚀 TurboShared v9.0"
    echo "🔗 $url"
    echo "════════════════════════════════════════"

    if [[ -n "$adet" ]]; then
        echo "📦 Profil indirme modu - $adet video"
        indir_profil "$url" "$adet"
    elif is_tiktok "$url"; then
        echo "📱 TikTok"
        indir_tiktok "$url"
    elif is_facebook "$url"; then
        echo "🔵 Facebook"
        indir_facebook "$url"
    else
        echo "🌐 Genel"
        indir_genel "$url"
    fi

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Tamamlandı!"
        termux-toast "✅ İndirildi"
    else
        echo ""
        echo "❌ Hata!"
        termux-toast "❌ Hata, link loglandı"
        echo "$url" >> "$LOG_FILE"
    fi

    tail -n +2 "$KUYRUK_FILE" > "$KUYRUK_FILE.tmp" && mv "$KUYRUK_FILE.tmp" "$KUYRUK_FILE"
done

termux-wake-unlock
rm -f "$KILIT_FILE"
echo ""
echo "🏁 Tüm indirmeler tamamlandı! 📍 $BASE_DIR/"
termux-toast "🏁 Tüm indirmeler tamamlandı!"
EOF
chmod +x ~/bin/turbo-worker.sh

rm -f ~/.turbo_kilit
echo -e "\e[1;32m✅ v9.0 hazır! Profil sorusu + güzel ilerleme çubuğu eklendi.\e[0m"
