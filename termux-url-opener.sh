#!/bin/bash

BASE_DIR="/storage/emulated/0/Download/TurboShared"
mkdir -p "$BASE_DIR"

# URL'yi temizle - TikTok Lite paylaşım metnini at, sadece linki al
url=$(echo "$1" | grep -oP 'https?://[^\s]+' | head -1)

echo "------------------------------------------"
echo "🚀 TurboShared v4.9 - TikTok Lite Destekli"
echo "🔗 Kaynak: $url"
echo "------------------------------------------"

# ─────────────────────────────────────────────
# URL TİPİ TESPİT FONKSİYONLARI
# ─────────────────────────────────────────────

is_tiktok_lite() {
    [[ $url == *"lite.tiktok.com"* ]] || \
    [[ $url == *"vm.tiktok.com"* ]] || \
    [[ $url == *"vt.tiktok.com"* ]] || \
    [[ $url == *"m.tiktok.com"* ]]
}

is_tiktok_profile() {
    [[ $url == *"tiktok.com/@"* ]] && [[ $url != *"/video/"* ]]
}

is_tiktok_video() {
    [[ $url == *"tiktok.com"* ]]
}

# ─────────────────────────────────────────────
# ORTAK YT-DLP AYARLARI (TikTok için optimize)
# ─────────────────────────────────────────────

TIKTOK_HEADERS=(
    --user-agent "Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36"
    --add-header "Referer:https://www.tiktok.com/"
    --add-header "Accept-Language:tr-TR,tr;q=0.9,en;q=0.8"
    --add-header "Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    --impersonate "chrome"
    --extractor-retries 5
    --retries 10
    --fragment-retries 10
)

# ─────────────────────────────────────────────
# TİKTOK LİTE / KISA LINK (vm. vt. m. lite.)
# ─────────────────────────────────────────────

if is_tiktok_lite; then
    echo "📱 TikTok Lite / Kısa link tespit edildi!"
    echo "📥 Video indiriliyor..."

    yt-dlp \
        "${TIKTOK_HEADERS[@]}" \
        --no-playlist \
        -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" \
        "$url"

    # Başarısız olursa yedek yöntem
    if [ $? -ne 0 ]; then
        echo ""
        echo "⚠️  Yedek yöntem deneniyor..."
        yt-dlp \
            "${TIKTOK_HEADERS[@]}" \
            --no-playlist \
            -f "b" \
            -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" \
            "$url"
    fi

# ─────────────────────────────────────────────
# TİKTOK PROFİL (Toplu İndirme)
# ─────────────────────────────────────────────

elif is_tiktok_profile; then
    echo "📌 TikTok profili tespit edildi!"
    read -p "📥 Kaç adet video indireyim? (Hepsi için 0 yaz): " adet

    if [[ $adet == "0" || -z $adet ]]; then
        echo "📂 Tüm videolar indiriliyor (sınırsız)"
        playlist_option=""
    else
        echo "📂 İlk $adet video indiriliyor"
        playlist_option="--playlist-items 1-$adet"
    fi

    echo "📂 Toplu mod → Kullanıcı adına göre klasör açılıyor"

    yt-dlp \
        $playlist_option \
        "${TIKTOK_HEADERS[@]}" \
        -f "bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        -o "$BASE_DIR/%(uploader)s/%(title).50s [%(id)s].%(ext)s" \
        "$url"

# ─────────────────────────────────────────────
# TİKTOK TEK VİDEO
# ─────────────────────────────────────────────

elif is_tiktok_video; then
    echo "🔗 TikTok tek video linki tespit edildi"
    echo "📂 Tekli mod → TurboShared klasörüne kaydediliyor"

    yt-dlp \
        --no-playlist \
        "${TIKTOK_HEADERS[@]}" \
        -f "bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" \
        "$url"

# ─────────────────────────────────────────────
# DİĞER PLATFORMLAR
# ─────────────────────────────────────────────

else
    echo "🌐 Diğer platform tespit edildi"
    echo "📂 Direkt TurboShared klasörüne kaydediliyor"

    yt-dlp \
        --no-playlist \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/121.0.0.0" \
        -f "bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" \
        "$url"
fi

# ─────────────────────────────────────────────
# SONUÇ
# ─────────────────────────────────────────────

echo "------------------------------------------"
if [ $? -eq 0 ]; then
    echo "✅ İşlem Tamam!"
    echo "📍 Konum: $BASE_DIR/"
else
    echo "❌ Bir hata oluştu."
    echo ""
    echo "💡 Öneriler:"
    echo "   1. yt-dlp'yi güncelle: yt-dlp -U"
    echo "   2. VPN dene (farklı ülke)"
    echo "   3. pip install curl_cffi --break-system-packages"
fi
echo "------------------------------------------"

read -p "Kapatmak için Enter'a bas..."
