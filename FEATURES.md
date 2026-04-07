# Argus — Ozellikler

## 1. Notch UI — Dynamic Island Tarzi Arayuz

- MacBook notch'unu gercek zamanli bir kontrol paneline donusturur
- **Compact bar**: Notch genisliginde minimal bar, durum gostergesi + animasyonlu pet ikonu
- **Expanded panel**: Hover ile acilan genis panel, session listesi, izin/soru/plan arayuzleri
- **Spring animasyonlar**: iOS Dynamic Island benzeri acilis/kapanis animasyonlari
- **Glow efekti**: Aktif session varken compact bar uzerinde kayan isik efekti
- **Pulse border**: Calisan session'larda nabiz atan kenar cizgisi
- **Bounce animasyonu**: Gorev tamamlandiginda notch'un hafifce ziplamasi
- Harici monitor destegi (notch olmayan ekranlarda da calisir, menu bar yuksekliginde sanal notch)

## 2. Izin Onaylama (Permission Approval)

- AI ajanin calistirmak istedigi komutlari/dosya islemlerini gosterir
- **Bash komutlari**: Monospaced font ile komut onizlemesi (`$ git push origin main`)
- **Dosya duzenlemeleri**: Dosya yolu gosterimi (Edit/Write)
- **Diff preview**: Dosya degisikliklerinin renkli onizlemesi (+eklemeler yesil, -silmeler kirmizi, satir sayilari)
- **3 aksiyon butonu**: Izin Ver (Cmd+Y), Reddet (Cmd+N), Hepsine Izin Ver
- "Hepsine Izin Ver" ile o tool icin session boyunca otomatik onay kurali olusturulur
- Staggered reveal animasyonu ile butonlar kademeli olarak belirir

## 3. Soru Yanitlama (Question Answering)

- AI ajanin sordugu sorulari notch'ta gosterir
- **Coktan secmeli**: Numarali secenekler, Cmd+1/2/3 kisayollari
- **Serbest metin**: Text field ile custom yanit yazma, Enter ile gonderme
- Soru metni + session basligi header'da gosterilir

## 4. Plan Inceleme (Plan Review)

- AI ajanin olusturdugu uygulama planini Markdown formatinda render eder
- ScrollView icinde plan icerik gosterimi
- **Geri bildirim alani**: Onaylamadan once text field ile yorum ekleme imkani
- Onayla (Cmd+Y) / Reddet (Cmd+N) butonlari
- Reddedildiginde geri bildirim otomatik eklenir

## 5. Coklu Oturum Yonetimi (Multi-Session)

- Ayni anda birden fazla AI kodlama oturumunu izleme
- **Session card'lari**: Her oturum icin renk kodlu durum gostergesi, kaynak ikon, baslik, son aktivite
- **Siralama**: Aktif oturumlar uste, idle olanlar alta
- **Durum makinesi**: idle, working, waiting, compacting, error, ended gecisleri
- **Otomatik kesif**: Uygulama acildiginda halihazirda calisan claude proceslerini otomatik bulur
- **Olum tespiti**: 5 saniyede bir PID kontrolu, kapanan session'lari otomatik temizler

## 6. 10 AI Ajan Destegi

- **Claude Code** — Tam entegrasyon (tum hook event'leri)
- **OpenAI Codex** — Hook destegi
- **Google Gemini CLI** — Farkli event mapping ile
- **Cursor** — Flat hook formati ile
- **GitHub Copilot** — Nested hook formati
- **OpenCode** — Nested hook formati
- **CodeBuddy** — Claude formati
- **Droid** — Nested hook formati
- **Qoder** — Claude formati
- **Factory** — Claude formati
- Her ajan icin ayarlardan tek tek acma/kapama, durum gosterimi

## 7. Hook Sistemi (Otomatik Entegrasyon)

- Ilk acilista hook'lari otomatik kurar, mevcut ayarlara dokunmaz
- **Non-destructive merge**: JSON config dosyalarina Argus bridge komutlarini ekler, varolan hook'lari korur
- **Backup**: Ilk degisiklikten once `.argus-backup` uzantili yedek alir
- **3 hook formati**: Claude (matcher + hooks array), nested (hooks array), flat (direct command)
- **Verify & repair**: 5 dakikada bir hook'larin sagligini kontrol eder, eksik olanlari onarir
- **Temiz kaldirma**: Ajan devre disi birakildiginda hook'lari tamamen temizler

## 8. Klavye Kisayollari

- **Cmd+Y**: Izin ver
- **Cmd+N**: Reddet
- **Cmd+1/2/3**: Soru secenekleri
- **Cmd+Shift+P**: Paneli ac/kapat
- Tum kisayollar ayarlardan ozellestirilebilir

## 9. Sesli Komutlar (Voice Commands)

- On-device konusma tanima, sunucuya veri gonderilmez
- **Turkce**: "izin ver", "reddet", "hepsine"
- **Ingilizce**: "allow", "deny", "allow all"
- Izin istegi geldiginde otomatik dinlemeye baslar
- Ayarlardan ac/kapat

## 10. Ses Bildirimleri (Sound Notifications)

- **8 farkli olay sesi**: Session basladi, bitti, izin gerekli, soru soruldu, plan hazir, gorev tamamlandi, hata, idle
- **3 katmanli ses sistemi**: Ozel ses dosyasi → Bundle .wav → macOS sistem sesi → Fallback beep
- Her olay icin ayri ayri ac/kapat
- Ozel ses dosyasi yukleme destegi (herhangi bir .wav/.mp3/.aiff)
- Volume kontrolu (0-100%)
- **Smart Suppress**: Kullanici zaten terminal/IDE'ye bakiyorsa gereksiz sesleri bastirir

## 11. Gorev Tamamlanma Karti (Completion Card)

- Basarili tamamlanmada animasyonlu yesil checkmark ikonu
- Session basligi + kaynak ajan ikonu
- Son mesaj onizlemesi
- "Terminale Git" butonu ile IDE/terminal'e tek tikla atlama
- 4 saniye sonra otomatik kapanir

## 12. Hata Karti (Error Card)

- Hata turune gore farkli ikonlar: rate limit, auth, billing, max tokens, genel hata
- Hata turune gore lokalize baslik
- Hata mesaji detayi
- "Tamam" ile kapatma

## 13. Idle Prompt (Bekleme Bildirimi)

- AI ajan kullanicidan yanit beklediginde nabiz atan turuncu gosterge
- Session basligi + "Git" butonu
- Tek tikla ilgili terminal/IDE'ye atlama

## 14. Terminal/IDE'ye Atlama (Jump to Session)

- **PID zinciri analizi**: claude process → parent PID → .app bundle tespiti
- 14 bilinen terminal/IDE destegi: Terminal, iTerm2, Ghostty, Warp, Alacritty, Kitty, VS Code, Cursor, Android Studio, IntelliJ, PyCharm, WebStorm, Fleet
- CWD eslestirmesi ile dogru pencereye atlama
- Fallback: Bilinen herhangi bir terminal'i aktive etme

## 15. Fullscreen Destegi

- Tam ekran uygulamalarda notch panelini gizler
- **5pt trigger zone**: Ekranin en ustune mouse goturunce gecici olarak gosterir
- Izin/soru bekleniyorsa otomatik gosterim
- 3 saniye sonra otomatik gizleme (bekleyen etkilesim yoksa)
- Ayarlardan fullscreen'de gosterimi ac/kapat

## 16. Desk Pet (Masaustu Evcil Hayvani)

- **Kediler**: 6 renk secenegi (Siyah, Turuncu, Beyaz, Gri, Calico, Colorpoint)
- **Kopekler**: 8 irk secenegi (Golden, Husky, Dalmatian, Rottweiler, Cane Corso, Dogo Argentino, Labrador, Pharaoh Hound)
- Sprite sheet animasyonlari: idle, run, sit, laydown, sleep
- **Duruma gore davranis**: Calisiyor=kosuyor, bekliyor=oturuyor, hata=yere yatiyor (dusme animasyonu ile), bitmis=uyuyor
- Boyut ayari (16-64px)
- Ayarlardan ac/kapat

## 17. Notch Durum Mascotlari (Pixel Pet)

- Compact bar'daki 8x8 piksel sanat mascotlari
- **7 stil**: Nokta (dot), Kedi, Kopek, Kus, Robot, Hayalet, Uzayli
- Her mascotun duruma gore farkli sprite'i (working=parlak gozler, waiting=etrafa bakma, error=aglama, idle=goz kirpma)
- 2 frame animasyon dongusu
- Bounce/sallanma animasyonlari

## 18. Gorunum Ozellestirme

- **Tema**: Karanlik, Acik, Sistem
- **7 vurgu rengi**: Turuncu, Mavi, Mor, Yesil, Kirmizi, Pembe, Cyan
- **Compact bar ozellestirme**: Genislik (dar/normal/genis), yukseklik (24-44pt), kose yuvarlakligi (4-24pt), font boyutu (9-16pt), yatay konum kaydirma (sol/orta/sag)
- **Kenar cizgisi**: Goster/gizle
- **Idle opaklik**: %10-%100 arasi ayarlanabilir

## 19. Lokalizasyon (9 Dil)

- Turkce, Ingilizce, Almanca, Ispanyolca, Fransizca, Japonca, Cince (Basitlestirilmis), Korece, Portekizce (Brezilya)
- Calisma zamaninda dil degistirme (uygulama yeniden baslatmaya gerek yok)
- Ayarlardan dil secimi veya sistem diline uyma

## 20. Otomatik Guncelleme

- Sparkle framework ile otomatik guncelleme kontrolu
- GitHub appcast.xml uzerinden versiyon takibi
- Ayarlardan manuel guncelleme kontrolu butonu

## 21. Coklu Monitor Destegi

- Ayarlardan hangi ekranda gorunecegini secme
- Otomatik mod: Notch'lu ekrani tercih eder
- Ekran degisikliklerini dinler, paneli otomatik yeniden konumlandirir

## 22. Gizlilik & Guvenlik

- Unix socket chmod 600 (sadece kullanici erisimi)
- Socket dizini chmod 700
- Sesli komutlar tamamen on-device islenir
- Mikrofon/konusma tanima izinleri acikca belirtilmis

## 23. Kurulum Secenekleri

- **DMG**: GitHub Releases'tan indirip surukleme
- **Homebrew**: `brew install --cask argus`
- **Gereksinimler**: macOS 15.0 (Sequoia)+, Apple Silicon veya Intel
