#!/bin/bash

BASE_DIR="/storage/emulated/0/Download/TurboShared"
mkdir -p "$BASE_DIR"

url=$1

echo "------------------------------------------"
echo "🚀 TurboShared v4.7 - Klasörlü Toplu İndirici"
echo "🔗 Kaynak: $url"
echo "------------------------------------------"

# Daha iyi tespit: Profil ise /@kullanıcı şeklinde veya video içermiyor
if [[ $url == *"tiktok.com/@"* ]] && [[ $url != *"/video/"* ]]; then
    echo "📌 TikTok **profili** tespit edildi!"
    read -p "📥 Kaç adet video indireyim? (Örn: 5, hepsi için 0 yaz): " adet

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
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/121.0.0.0" \
        --add-header "Referer:https://www.tiktok.com/" \
        -f "bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        -o "$BASE_DIR/%(uploader)s/%(title).50s [%(id)s].%(ext)s" \
        "$url"

else
    echo "🔗 Tek video linki tespit edildi"
    echo "📂 Tekli mod → Direkt TurboShared klasörüne kaydediliyor (alt klasör yok)"

    yt-dlp \
        --no-playlist \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/121.0.0.0" \
        -f "bestvideo+bestaudio/best" \
        --merge-output-format mp4 \
        -o "$BASE_DIR/%(title).50s [%(id)s].%(ext)s" \
        "$url"
fi

if [ $? -eq 0 ]; then
    echo "------------------------------------------"
    echo "✅ İşlem Tamam!"
    echo "📍 Konum: $BASE_DIR/"
else
    echo "------------------------------------------"
    echo "❌ Bir hata oluştu. Linki veya interneti kontrol et."
    echo "   Not: TikTok bazen engelliyor, VPN deneyebilirsin."
fi

read -p "Kapatmak için Enter'a bas..."
