# Argus

MacBook notch'unu AI kodlama ajanları icin gercek zamanli kontrol paneline donusturen native macOS uygulamasi.

**[Vibe Island](https://github.com/nicepkg/vibe-island)'in ucretsiz, acik kaynak alternatifi.**

## Ozellikler

- **Notch UI** — Compact bar + expanded panel, Dynamic Island tarzi animasyonlar
- **Claude Code entegrasyonu** — Hook-tabanli gercek zamanli iletisim
- **Izin onaylama** — Allow/Deny + diff preview, Cmd+Y/N kisayollari
- **Soru yanitlama** — Coktan secmeli + serbest metin, Cmd+1/2/3
- **Plan inceleme** — Markdown render + geri bildirim
- **Coklu oturum** — Birden fazla Claude Code oturumunu ayni anda izleme
- **Ses bildirimleri** — 8-bit sesler + ozel ses destegi
- **Ayarlar** — Tema, ses, kisayollar, hook yonetimi
- **Fullscreen destek** — Hover trigger zone ile tam ekranda calisma
- **Lokalizasyon** — Turkce + Ingilizce

## Kurulum

### DMG ile

1. [Releases](https://github.com/cnrture/Argus/releases) sayfasindan en son DMG'yi indirin
2. Argus.app'i Applications klasorune surukleyin
3. Ilk acilista hook kurulum izni verin

### Homebrew ile

```bash
brew install --cask argus
```

## Gereksinimler

- macOS 15.0 (Sequoia) veya uzeri
- Apple Silicon veya Intel Mac

## Mimari

```
Claude Code Hook → argus-bridge (Swift CLI) → Unix Socket → Argus.app → Notch UI
```

- **argus-bridge**: Swift CLI binary — sifir dis bagimlilik
- **Unix Socket**: `~/.argus/argus.sock` (chmod 600)
- **Hook merge**: Mevcut hook'lara dokunmaz, yedek alir

## Gelistirme

```bash
# Build
make build

# Bridge build
make bridge

# Clean
make clean
```

## Lisans

MIT License — detaylar icin [LICENSE](LICENSE) dosyasina bakin.
