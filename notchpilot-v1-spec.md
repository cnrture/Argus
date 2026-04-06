# NotchPilot V1 — Final Spesifikasyon

> MacBook notch'unu AI kodlama ajanları için gerçek zamanlı kontrol paneline dönüştüren native macOS uygulaması.
> Vibe Island'ın ücretsiz, açık kaynak alternatifi.

---

## 1. Proje Bilgileri

| Alan | Değer |
|------|-------|
| Uygulama Adı | **NotchPilot** |
| Repo | `github.com/cnrture/NotchPilot` |
| Lisans | MIT License |
| Dağıtım | GitHub Releases (DMG) + Homebrew Cask |
| Min macOS | 15.0 (Sequoia) |
| Mimari | Universal (Apple Silicon + Intel) |
| Dil | Swift 6 |
| UI Framework | SwiftUI + AppKit (NSPanel) |
| Paket Yönetimi | Swift Package Manager |
| Code Signing | Apple Developer ID + Notarization |
| CI/CD | GitHub Actions (tag push → release) |

---

## 2. V1 Kapsam Özeti

V1'de yer alan özellikler:

| Modül | Durum |
|-------|-------|
| Notch UI (compact + expanded + harici monitör) | V1 |
| Claude Code hook entegrasyonu | V1 |
| Çoklu oturum izleme | V1 |
| İzin onaylama (Allow/Deny + diff preview) | V1 |
| Soru yanıtlama (butonlar + text field) | V1 |
| Plan inceleme (Markdown render) | V1 |
| Ses bildirimleri (8-bit, olay bazlı) | V1 |
| Ayarlar penceresi (tema, ses, kısayollar) | V1 |
| Dark / Light / System tema | V1 |
| Keyboard shortcuts | V1 |
| "Bu oturumda hep izin ver" toplu onay | V1 |

V1'de **olmayan** özellikler:
- Çoklu ajan desteği (Codex, Gemini vb.) → V2
- Terminal atlama → V2
- Kullanım istatistikleri → V2
- Plugin sistemi → V3

---

## 3. Mimari

### 3.1 Üst Düzey Bileşenler

```
┌─────────────────────────────────────────────────────┐
│                    NotchPilot.app                     │
│                                                       │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │ NotchUI   │  │ SessionMgr   │  │  SettingsStore │ │
│  │ (SwiftUI) │  │              │  │  (UserDefaults)│ │
│  └─────┬─────┘  └──────┬───────┘  └────────────────┘ │
│        │               │                              │
│        └───────┬───────┘                              │
│                │                                      │
│         ┌──────┴───────┐                              │
│         │ SocketServer │ ← Unix Domain Socket         │
│         │ (JSONL)      │                              │
│         └──────┬───────┘                              │
│                │                                      │
└────────────────┼──────────────────────────────────────┘
                 │
      ┌──────────┴──────────┐
      │  notchpilot-bridge  │ ← Swift CLI binary
      │  (stdin → socket)   │
      └──────────┬──────────┘
                 │
      ┌──────────┴──────────┐
      │  Claude Code Hooks  │ ← ~/.claude/settings.json
      │  (SessionStart,     │
      │   PermissionRequest,│
      │   Stop, etc.)       │
      └─────────────────────┘
```

### 3.2 Veri Akışı

```
Claude Code hook tetiklenir
  → notchpilot-bridge stdin'den JSON alır
  → Unix socket'e JSONL olarak gönderir
  → SocketServer parse eder → SessionManager günceller
  → NotchUI reaktif olarak güncellenir (@Published)
  → Kullanıcı etkileşimi (Allow/Deny/Answer)
  → Yanıt socket üzerinden bridge'e döner
  → Bridge stdout'a JSON yazar → Claude Code alır
```

### 3.3 Blokaj Akışı (PermissionRequest)

```
Claude Code izin ister
  → Hook bridge'i çağırır (blocking — yanıt bekler)
  → Bridge socket'e bağlanır, event gönderir
  → App notch'u genişletir, Allow/Deny gösterir
  → Kullanıcı tıklar veya Cmd+Y/N basar
  → Yanıt JSON olarak bridge'e döner
  → Bridge stdout'a yazar:
    {"hookSpecificOutput": {"hookEventName": "PermissionRequest",
     "decision": {"behavior": "allow"}}}
  → Claude Code devam eder
```

---

## 4. Notch UI Detaylı Tasarım

### 4.1 Pencere Sistemi

> Claude Island'dan alınan kanıtlanmış pattern'ler ile.

| Özellik | Değer |
|---------|-------|
| Pencere tipi | `NSPanel` with `.nonactivatingPanel` style mask |
| Level | `.mainMenu + 3` (menu bar + diğer overlay'lerin üstünde) |
| Collection behavior | `.fullScreenAuxiliary`, `.stationary`, `.canJoinAllSpaces`, `.ignoresCycle` |
| Background | `NSVisualEffectView` with `.hudWindow` material |
| Corner radius | Animasyonlu: kapalı `top:6, bottom:14` → açık `top:19, bottom:24` |
| Mouse handling | **Dinamik toggle**: kapalıyken `ignoresMouseEvents = true`, açıkken `false` |

#### PassThroughHostingView (Kritik Pattern)

Claude Island'dan alınan en önemli pattern. NSHostingView'ı override ederek panel dışındaki tıklamaların menu bar'a geçmesini sağlar:

```swift
class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var hitTestRect: CGRect = .zero  // Dinamik olarak panel boyutuna göre güncellenir

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hitTestRect.contains(point) else { return nil } // Dışarıdaki tıklamalar geçer
        return super.hitTest(point)
    }
}
```

#### Pencere Oluşturma

```swift
// NotchPanel: NSPanel
let panel = NSPanel(
    contentRect: windowFrame,
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.level = .mainMenu + 3
panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false

// Kapalıyken → tıklamalar menu bar'a geçer
panel.ignoresMouseEvents = true

// Açıldığında → butonlar çalışır
func onPanelExpand() { panel.ignoresMouseEvents = false }
func onPanelCollapse() { panel.ignoresMouseEvents = true }
```

#### Focus Yönetimi (Bildirimde Focus Çalmama)

```swift
// İzin isteği geldiğinde: panel açılır AMA terminal'den focus çalınmaz
func showPermissionRequest() {
    expandPanel()
    // makeKey() veya NSApp.activate() ÇAĞRILMAZ
    // Kullanıcı butonlara tıklayınca panel zaten çalışır (.nonactivatingPanel sayesinde)
}

// Kullanıcı panele tıkladığında: sadece o zaman ön plana al
func onUserClick() {
    panel.makeKey()
}
```

### 4.2 Notch Pozisyon Hesaplama

> Claude Island + boring.notch'tan alınan ampirik düzeltmeler ile.

```swift
// NSScreen extension
extension NSScreen {
    var hasPhysicalNotch: Bool {
        safeAreaInsets.top > 0
    }

    var notchSize: CGSize {
        guard hasPhysicalNotch else {
            // Harici monitör / notch'suz Mac: pill-shaped bar boyutu
            return CGSize(width: 224, height: 38)
        }
        let notchHeight = safeAreaInsets.top
        let fullWidth = frame.width
        let leftPadding = auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = auxiliaryTopRightArea?.width ?? 0
        guard leftPadding > 0, rightPadding > 0 else {
            return CGSize(width: 180, height: notchHeight)
        }
        // +4: boring.notch'tan alınan ampirik düzeltme (pixel-perfect hizalama)
        let notchWidth = fullWidth - leftPadding - rightPadding + 4
        return CGSize(width: notchWidth, height: notchHeight)
    }

    var isBuiltinDisplay: Bool {
        CGDisplayIsBuiltin(displayID) != 0
    }

    private var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}
```

#### Pencere Pozisyonlama

```swift
let screen = selectedScreen ?? NSScreen.main!
let screenFrame = screen.frame
let notchSize = screen.notchSize
let windowHeight: CGFloat = 750 // Expanded state için yeterli yükseklik

let windowFrame = NSRect(
    x: screenFrame.origin.x,
    y: screenFrame.maxY - windowHeight,
    width: screenFrame.width,
    height: windowHeight
)

// Notch rect (pencere koordinatlarında, üst sol köşe)
let deviceNotchRect = CGRect(
    x: (screenFrame.width - notchSize.width) / 2,
    y: 0,
    width: notchSize.width,
    height: notchSize.height
)
```

#### Çoklu Monitör Desteği

> Claude Island'dan alınan persistent screen identification pattern'i.

```swift
struct ScreenIdentifier: Codable, Equatable, Hashable {
    let displayID: CGDirectDisplayID?
    let localizedName: String

    func matches(_ screen: NSScreen) -> Bool {
        // Birincil: displayID eşleşmesi (en güvenilir)
        if let savedID = displayID, savedID == screen.displayID { return true }
        // Yedek: isim eşleşmesi (monitör yeniden bağlandığında ID değişebilir)
        return localizedName == screen.localizedName
    }
}

// ScreenSelector: Üç strateji
enum ScreenSelection: Codable {
    case automatic       // Dahili ekranı tercih et, yoksa NSScreen.main
    case specific(ScreenIdentifier)  // Kullanıcının seçtiği monitör
}
```

#### Ekran Değişikliği Algılama (ScreenObserver)

```swift
class ScreenObserver {
    init(onScreenChange: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { _ in
            onScreenChange() // Pencereyi yeniden oluştur/konumla
        }
    }
}
```

**Harici monitörde (notch yok):**
- **Pill-shaped floating bar** olarak gösterilir (sahte notch dikdörtgeni yerine)
- Ekranın üst ortasında, menu bar yüksekliğinin hemen altında
- Aynı genişlik kuralları geçerli
- Ayarlarda hangi monitörde gösterileceği seçilebilir

### 4.3 UI State'leri

#### State 1: Hidden
- Aktif oturum yok
- Panel tamamen gizli
- Sadece menu bar icon'u görünür

#### State 2: Compact (Varsayılan)
```
┌──────────────────────────────────────────────┐
│  🟢 My Project — Claude Code    ⏱ 12:34     │
└──────────────────────────────────────────────┘
     ↑          ↑                    ↑
  Durum      Oturum başlığı      Süre sayacı
  noktası
```
- Genişlik: Notch genişliğinin ~1.5 katı
- Yükseklik: ~32pt
- Notch'un hemen altında, ortalanmış
- Durum noktası renkleri:
  - 🟢 Yeşil: idle (Claude yanıt tamamladı, girdi bekliyor)
  - 🔵 Mavi: working (Claude çalışıyor)
  - 🟠 Turuncu: waiting (izin veya yanıt bekliyor)
  - 🔴 Kırmızı: error
- Çoklu oturum varsa: aktif oturum + badge sayısı `(3)`

#### State 3: Expanded — Overview (Hover ile tetiklenir)
```
┌───────────────────────────────────────────────────────────┐
│                      NotchPilot                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ 🟢 alphaz-flutter — Claude Code         ⏱ 12:34   │  │
│  │    Son: "Login ekranını düzenliyorum..."             │  │
│  ├─────────────────────────────────────────────────────┤  │
│  │ 🔵 backend-api — Claude Code             ⏱ 03:21   │  │
│  │    Son: "API endpoint'lerini oluşturuyorum..."       │  │
│  ├─────────────────────────────────────────────────────┤  │
│  │ 🟡 web-dashboard — Claude Code (idle)    ⏱ 45:12   │  │
│  │    15 dk+ hareketsiz                                │  │
│  └─────────────────────────────────────────────────────┘  │
│  🔇 Ses   ⚙️ Ayarlar                                     │
└───────────────────────────────────────────────────────────┘
```
- Genişlik: Notch genişliğinin **3 katı** (max 600pt)
- Spring animasyon ile genişleme (damping: 0.7, response: 0.4)
- Her oturum kartı tıklanabilir → detay/etkileşim paneline geçer
- Idle oturumlar (15dk+) soluk renkte, tek satır

#### State 4: Expanded — Permission Approval (Otomatik tetiklenir)
```
┌───────────────────────────────────────────────────────────┐
│  🟠 alphaz-flutter — İzin Gerekli                        │
│                                                           │
│  Bash aracını çalıştırmak istiyor:                       │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ $ flutter build apk --flavor dev                    │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ☐ Bu oturumda Bash için hep izin ver                    │
│                                                           │
│       [ ✕ Reddet (⌘N) ]        [ ✓ İzin Ver (⌘Y) ]      │
└───────────────────────────────────────────────────────────┘
```

**Edit/Write araçları için diff preview:**
```
┌───────────────────────────────────────────────────────────┐
│  🟠 alphaz-flutter — İzin Gerekli                        │
│                                                           │
│  Edit: lib/core/constants/app_colors.dart                 │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  - static const primary = Color(0xFF1A1A2E);       │  │
│  │  + static const primary = Color(0xFF6C63FF);       │  │
│  │                                                     │  │
│  │  - static const accent = Color(0xFFE94560);        │  │
│  │  + static const accent = Color(0xFFFF6B6B);        │  │
│  └─────────────────────────────────────────────────────┘  │
│  +2 −2 satır değişiklik                                   │
│                                                           │
│  ☐ Bu oturumda Edit için hep izin ver                    │
│                                                           │
│       [ ✕ Reddet (⌘N) ]        [ ✓ İzin Ver (⌘Y) ]      │
└───────────────────────────────────────────────────────────┘
```

#### State 5: Expanded — Question (Otomatik tetiklenir)
```
┌───────────────────────────────────────────────────────────┐
│  🟠 alphaz-flutter — Soru                                │
│                                                           │
│  Hangi state management yaklaşımını tercih ediyorsun?     │
│                                                           │
│  [ 1. BLoC/Cubit (⌘1) ]                                 │
│  [ 2. Riverpod (⌘2) ]                                   │
│  [ 3. Provider (⌘3) ]                                   │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

**Serbest metin sorusu:**
```
┌───────────────────────────────────────────────────────────┐
│  🟠 alphaz-flutter — Soru                                │
│                                                           │
│  Proje için hangi veritabanını kullanmak istiyorsun?      │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Yanıtınızı yazın...                          [Gönder]│  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

#### State 6: Expanded — Plan Review (Otomatik tetiklenir)
```
┌───────────────────────────────────────────────────────────┐
│  🟠 alphaz-flutter — Plan İnceleme                       │
│                                                           │
│  ## Implementasyon Planı                                  │
│                                                           │
│  1. **UserRepository** oluştur                            │
│     - `lib/data/repositories/user_repository.dart`        │
│     - CRUD operasyonları                                  │
│  2. **UserCubit** ekle                                    │
│     - State management                                    │
│     - Error handling                                      │
│  3. **ProfileScreen** güncelle                            │
│     ```dart                                               │
│     final cubit = context.read<UserCubit>();              │
│     ```                                                   │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Geri bildirim yazın... (opsiyonel)                  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│       [ ✕ Reddet (⌘N) ]        [ ✓ Onayla (⌘Y) ]        │
└───────────────────────────────────────────────────────────┘
```

### 4.4 Animasyonlar

> Claude Island'ın kanıtlanmış animasyon parametreleri + ek efektler ile.

**Açılma ve kapanma için farklı spring parametreleri** (daha doğal his):

```swift
// Açılma: biraz bouncy, canlı
let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)

// Kapanma: overdamped, hızlı ve kesin
let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
```

**NotchShape — animasyonlu köşe yarıçapı:**

```swift
struct NotchShape: Shape {
    var topCornerRadius: CGFloat    // Kapalı: 6, Açık: 19
    var bottomCornerRadius: CGFloat // Kapalı: 14, Açık: 24

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set { topCornerRadius = newValue.first; bottomCornerRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        // Quadratic curves ile notch şekli — köşeler animate edilir
    }
}
```

| Geçiş | Süre | Detay |
|--------|------|-------|
| Hidden → Compact | 0.3s | Fade in + scale from 0.8 |
| Compact → Expanded | 0.42s | `openAnimation` — spring genişleme, köşeler yuvarlanır |
| Expanded → Compact | 0.45s | `closeAnimation` — overdamped kapanma, köşeler daralır |
| State değişimi (Permission geldi) | 0.35s | Crossfade + height animation |
| Oturum kartı ekleme | 0.3s | Slide in from top + fade |
| Oturum kartı kaldırma | 0.25s | Slide out + fade |
| Durum noktası renk değişimi | 0.5s | Smooth color transition |

**Ek animasyonlar (Claude Island'dan):**

| Animasyon | Detay |
|-----------|-------|
| **Boot animation** | İlk açılışta 1 saniyelik aç-kapa (hoş ilk izlenim) |
| **Bounce on complete** | Claude tamamlandığında 150ms mini zıplama efekti |
| **Staggered button reveal** | İzin butonları (Reddet, İzin Ver) 50ms arayla belirme |
| **Expanding compact** | Working/waiting durumunda compact bar yanlara genişler (Dynamic Island tarzı) |

### 4.5 Fullscreen Uygulama Davranışı

> Claude Island bu sorunu çözmemiş — bizim fark yaratacağımız alan.

**Window collection behavior zaten fullscreen'i destekliyor:**
```swift
collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
```

**Ek çözümlerimiz:**
- `NSWorkspace.shared.notificationCenter` ile fullscreen geçiş algılama
- Fullscreen'de panel varsayılan olarak gizli
- Kullanıcı mouse'u ekranın üst kenarına getirdiğinde (~5pt trigger zone) panel görünür
- İzin/soru isteği geldiğinde fullscreen'de bile otomatik gösterilir
- 3 saniye hareketsizlikten sonra tekrar gizlenir
- Ayarlarda "Fullscreen'de göster" toggle'ı ile devre dışı bırakılabilir

---

## 5. Hook Entegrasyonu

### 5.1 Desteklenen Hook Olayları

| Hook Event | Yön | Blocking | Kullanım |
|------------|-----|----------|----------|
| `SessionStart` | Claude → App | Hayır | Yeni oturum kartı oluştur |
| `SessionEnd` | Claude → App | Hayır | Oturum kartını kaldır |
| `Stop` | Claude → App | Hayır | Durum → idle, ses çal |
| `PreToolUse` | Claude → App | Hayır | Durum → working göster |
| `PostToolUse` | Claude → App | Hayır | Son araç bilgisini güncelle |
| `PermissionRequest` | Claude → App → Claude | **Evet** | İzin paneli göster, yanıt bekle |
| `Notification` | Claude → App | Hayır | Bildirim tipine göre işle |
| `UserPromptSubmit` | Claude → App | Hayır | Durum → working |
| `PreCompact` | Claude → App | Hayır | Durum → compacting göster |
| `SubagentStop` | Claude → App | Hayır | Alt-ajan tamamlandı bildirimi |

### 5.2 Akıllı Hook Merge Algoritması

> Claude Island'ın merge yaklaşımı + bizim yedekleme iyileştirmemiz.

```
1. ~/.claude/settings.json dosyasını oku (yoksa boş dict ile başla)
2. JSON parse et
3. ** YEDEKle: settings.json → settings.json.notchpilot-backup **
   (Claude Island bunu YAPMIYOR — bizim güvenlik katmanımız)
4. "hooks" anahtarı yoksa → oluştur
5. Her event tipi için:
   a. Mevcut array'i al (yoksa boş array)
   b. NotchPilot hook'u zaten var mı kontrol et
      (command içinde "notchpilot-bridge" geçiyorsa → var)
   c. Yoksa → array'in SONUNA ekle (mevcut hook'ların önceliği korunur)
   d. Varsa → command path'ini güncelle (versiyon yükseltme durumu)
6. Diğer tüm hook'lara KESİNLİKLE DOKUNMA
7. Dosyayı geri yaz (pretty-printed JSON, 2 space indent)
8. Yazma hatası olursa → backup'tan geri yükle + kullanıcıya bildir
```

#### Temiz Kaldırma (Uninstall)

```
1. settings.json'u oku
2. Her event array'inde "notchpilot-bridge" içeren hook'ları SİL
3. Array boş kaldıysa → event key'ini de sil
4. Diğer hook'lara dokunma
5. Dosyayı geri yaz
```

#### Tool Use ID Cache (Kritik — Claude Code API Eksikliği)

> Claude Island'dan alınan kritik pattern. `PermissionRequest` event'i `tool_use_id` İÇERMEZ.
> Bu ID'yi `PreToolUse`'dan (ki PermissionRequest'ten hemen önce tetiklenir) cache'lemek gerekir.

```swift
// SessionManager'da FIFO cache
// Key: "\(sessionId):\(toolName):\(serializedInput)"
// Value: tool_use_id
private var toolUseIdCache: [String: String] = [:]

func onPreToolUse(sessionId: String, toolName: String, toolInput: [String: Any], toolUseId: String) {
    let key = "\(sessionId):\(toolName):\(serialize(toolInput))"
    toolUseIdCache[key] = toolUseId
}

func onPermissionRequest(sessionId: String, toolName: String, toolInput: [String: Any]) -> String? {
    let key = "\(sessionId):\(toolName):\(serialize(toolInput))"
    return toolUseIdCache.removeValue(forKey: key) // Kullan ve sil
}
```

### 5.3 Hook Yapılandırması (Otomatik Yazılacak)

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge session-start",
        "timeout": 5
      }]
    }],
    "SessionEnd": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge session-end",
        "timeout": 5
      }]
    }],
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge stop",
        "timeout": 5
      }]
    }],
    "PreToolUse": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge pre-tool-use",
        "timeout": 5
      }]
    }],
    "PostToolUse": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge post-tool-use",
        "timeout": 5
      }]
    }],
    "PermissionRequest": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge permission-request",
        "timeout": 86400
      }]
    }],
    "Notification": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge notification",
        "timeout": 5
      }]
    }],
    "UserPromptSubmit": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge user-prompt-submit",
        "timeout": 5
      }]
    }],
    "PreCompact": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge pre-compact",
        "timeout": 5
      }]
    }],
    "SubagentStop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.notchpilot/bin/notchpilot-bridge subagent-stop",
        "timeout": 5
      }]
    }]
  }
}
```

> **Not:** `PermissionRequest` timeout'u **86400 saniye (24 saat)** — Claude Island'ın kanıtlanmış değeri. Claude Code'un hook'u timeout etmemesi için çok yüksek tutulur. Gerçek timeout socket seviyesinde yönetilir. `PreCompact` ve `SubagentStop` da eklendi. Diğerleri 5 saniye.

### 5.4 Bridge Binary Detayı

**Konum:** `~/.notchpilot/bin/notchpilot-bridge`

İlk çalıştırmada app tarafından buraya kopyalanır (`Contents/Resources/notchpilot-bridge` → `~/.notchpilot/bin/`).

**Çalışma akışı:**
```
1. argv[1]'den event tipini al (session-start, permission-request, vb.)
2. stdin'den JSON'u oku (Claude Code hook input)
3. ~/.notchpilot/notchpilot.sock Unix socket'ine bağlan
4. JSONL mesajı gönder: {"event": "permission-request", "data": {...}}
5. Blocking event ise → socket'ten yanıt bekle
6. Non-blocking ise → hemen çık (exit 0)
7. Yanıt gelince stdout'a yaz → exit 0
8. Socket bağlantı hatası → stderr'e log → exit 1 (non-blocking error)
```

**Hata toleransı:**
- Socket bulunamazsa (app kapalı) → sessizce exit 1 (Claude Code akışını engellemez)
- Timeout → exit 1
- JSON parse hatası → stderr log + exit 1

#### Socket Güvenliği

> Claude Island `/tmp/claude-island.sock` + `chmod 0o777` kullanıyor — güvenlik açığı (Issue #48).

```swift
// NotchPilot: Güvenli yaklaşım
let socketPath = "\(NSHomeDirectory())/.notchpilot/notchpilot.sock"
// ~/.notchpilot/ dizini — sadece kullanıcıya ait
FileManager.default.createDirectory(at: socketDir, withIntermediateDirectories: true)
chmod(socketPath, 0o700) // Sadece sahibi okuyabilir/yazabilir
```

- **Konum:** `~/.notchpilot/notchpilot.sock` (`/tmp/` yerine — diğer kullanıcılar erişemez)
- **İzinler:** `chmod 0o700` (sadece dosya sahibi)
- **Auto-recovery:** Socket dosyası silinirse → otomatik yeniden oluşturma
- **Pending permission cleanup:** Session end'de tüm bekleyen izinler temizlenir
- **PostToolUse cancellation:** Terminalden onaylanan izinler otomatik iptal edilir

---

## 6. İletişim Protokolü (JSONL)

### 6.1 Bridge → App (Event)

```json
{"id":"evt_1234","event":"session-start","timestamp":"2026-04-07T14:30:00Z","session_id":"abc123","cwd":"/Users/candroid/project","data":{"session_id":"abc123"}}
```

```json
{"id":"evt_1235","event":"permission-request","timestamp":"2026-04-07T14:30:05Z","session_id":"abc123","data":{"tool_name":"Bash","tool_input":{"command":"flutter build apk"},"tool_use_id":"toolu_01ABC"}}
```

```json
{"id":"evt_1236","event":"permission-request","timestamp":"2026-04-07T14:30:10Z","session_id":"abc123","data":{"tool_name":"Edit","tool_input":{"file_path":"lib/main.dart","old_string":"const title = 'Old'","new_string":"const title = 'New'"},"tool_use_id":"toolu_02DEF"}}
```

### 6.2 App → Bridge (Response)

**İzin onayı:**
```json
{"id":"evt_1235","response":{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}}
```

**İzin reddi:**
```json
{"id":"evt_1235","response":{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","reason":"Kullanıcı tarafından reddedildi"}}}}
```

**Soru yanıtı:**
```json
{"id":"evt_1237","response":{"hookSpecificOutput":{"hookEventName":"Elicitation","selectedOption":"BLoC/Cubit"}}}
```

---

## 7. Veri Modelleri

### 7.1 Session

```swift
@Observable
final class Session: Identifiable {
    let id: String              // Claude Code session_id
    let startTime: Date
    var title: String           // Proje/dizin adı
    var status: SessionStatus
    var lastActivity: Date
    var lastToolName: String?
    var lastStatusText: String? // "Login ekranını düzenliyorum..."
    var pendingPermission: PermissionEvent?
    var pendingQuestion: QuestionEvent?
    var pendingPlan: PlanEvent?
    var autoApproveRules: Set<String> // "Bu oturumda Bash hep izin ver"

    var isIdle: Bool {
        Date().timeIntervalSince(lastActivity) > idleTimeout
    }
}

enum SessionStatus: String, Codable {
    case working    // 🔵 Claude çalışıyor
    case idle       // 🟢 Girdi bekliyor
    case waiting    // 🟠 İzin/yanıt bekliyor
    case compacting // 🔵 Bağlam sıkıştırılıyor
    case error      // 🔴 Hata
    case ended      // Oturum bitti

    /// Claude Island'dan: Geçerli durum geçişlerini doğrula
    func canTransition(to next: SessionStatus) -> Bool {
        switch (self, next) {
        case (.idle, .working), (.idle, .waiting), (.idle, .ended):       return true
        case (.working, .idle), (.working, .waiting), (.working, .error): return true
        case (.waiting, .working), (.waiting, .idle):                     return true
        case (.compacting, .idle), (.compacting, .working):               return true
        case (_, .ended):                                                  return true
        default:                                                           return false
        }
    }
}
```

### 7.5 SessionStore (Actor Pattern)

> Claude Island'dan alınan thread-safe state management pattern'i.

```swift
/// Tek kaynak gerçeklik (single source of truth) — tüm state değişimleri buradan geçer
actor SessionStore {
    private var sessions: [String: Session] = [:]
    private let subject = CurrentValueSubject<[Session], Never>([])

    /// UI bu publisher'a subscribe olur
    var sessionsPublisher: AnyPublisher<[Session], Never> {
        subject.eraseToAnyPublisher()
    }

    func process(_ event: HookEvent) {
        switch event.event {
        case .sessionStart:
            let session = Session(id: event.sessionId, ...)
            sessions[event.sessionId] = session
        case .permissionRequest:
            sessions[event.sessionId]?.status = .waiting
            sessions[event.sessionId]?.pendingPermission = ...
        case .stop:
            sessions[event.sessionId]?.status = .idle
        case .sessionEnd:
            sessions.removeValue(forKey: event.sessionId)
        // ... diğer event'ler
        }
        subject.send(Array(sessions.values))
    }
}
```
```

### 7.2 HookEvent

```swift
struct HookEvent: Codable, Identifiable {
    let id: String
    let event: HookEventType
    let timestamp: Date
    let sessionId: String
    let cwd: String?
    let data: HookEventData
}

enum HookEventType: String, Codable {
    case sessionStart = "session-start"
    case sessionEnd = "session-end"
    case stop
    case preToolUse = "pre-tool-use"
    case postToolUse = "post-tool-use"
    case permissionRequest = "permission-request"
    case notification
    case userPromptSubmit = "user-prompt-submit"
}

struct HookEventData: Codable {
    let sessionId: String?
    let toolName: String?
    let toolInput: [String: AnyCodable]?
    let toolUseId: String?
    let hookEventName: String?
}
```

### 7.3 Permission Event

```swift
struct PermissionEvent: Identifiable {
    let id: String          // event id
    let toolName: String    // "Bash", "Edit", "Write"
    let toolInput: ToolInput
    let toolUseId: String
    let receivedAt: Date

    var displayCommand: String { /* tool_input'tan okunabilir komut */ }
    var diffPreview: DiffPreview? { /* Edit/Write için diff */ }
}

struct DiffPreview {
    let filePath: String
    let additions: [String]
    let deletions: [String]
    let addedCount: Int
    let deletedCount: Int
}
```

### 7.4 Settings

```swift
@Observable
final class SettingsStore {
    // Görünüm
    var theme: AppTheme = .system          // .dark, .light, .system
    var accentColor: Color = .orange

    // Ses
    var soundEnabled: Bool = true
    var soundVolume: Float = 0.7           // 0.0 - 1.0
    var soundPack: SoundPack = .eightBit
    var customSoundDirectory: URL?         // Özel ses dizini
    var soundEvents: [SoundEventConfig] = SoundEventConfig.defaults

    // Bildirimler
    var nativeNotificationsEnabled: Bool = false

    // Davranış
    var launchAtLogin: Bool = false
    var idleTimeout: TimeInterval = 900    // 15 dakika (saniye)
    var autoSetupHooks: Bool = true
    var showInFullscreen: Bool = true

    // Kısayollar
    var allowShortcut: KeyboardShortcut = .init(.y, modifiers: .command)
    var denyShortcut: KeyboardShortcut = .init(.n, modifiers: .command)
}

enum AppTheme: String, CaseIterable {
    case dark, light, system
}

struct SoundEventConfig: Identifiable {
    let id: String
    let eventType: SoundTrigger
    var enabled: Bool
    var customSoundURL: URL?   // nil = varsayılan 8-bit ses
}

enum SoundTrigger: String, CaseIterable {
    case sessionStarted = "Oturum Başladı"
    case sessionEnded = "Oturum Bitti"
    case permissionNeeded = "İzin Bekliyor"
    case questionAsked = "Soru Soruldu"
    case planReady = "Plan Hazır"
    case taskCompleted = "Görev Tamamlandı"
    case error = "Hata Oluştu"
    case idle = "Hareketsiz"
}
```

---

## 8. Ses Sistemi

### 8.1 Varsayılan 8-Bit Sesler

Her olay tipi için kısa (0.3-1.0 saniye) 8-bit chiptune ses efektleri:

| Olay | Ses Karakteri | Süre |
|------|---------------|------|
| Oturum Başladı | Yükselen arpej (do-mi-sol) | 0.5s |
| Oturum Bitti | İnen arpej (sol-mi-do) | 0.5s |
| İzin Bekliyor | Dikkat çekici bip-bip (tekrarlı) | 0.8s |
| Soru Soruldu | Soru işareti melodisi (yükselen iki nota) | 0.4s |
| Plan Hazır | Bildirim chime | 0.5s |
| Görev Tamamlandı | Zafer fanfarı (kısa) | 0.7s |
| Hata | Düşük ton buzz | 0.3s |
| Hareketsiz | Yumuşak ping | 0.3s |

### 8.2 Ses Üretimi

- `AVAudioEngine` + `AVAudioSourceNode` ile programatik ses üretimi
- Veya önceden oluşturulmuş `.wav` dosyaları (`Resources/Sounds/`)
- V1'de dosya tabanlı daha pratik

### 8.3 Özel Ses Desteği

- Ayarlarda her olay tipi için ayrı ses dosyası seçilebilir
- Desteklenen formatlar: `.wav`, `.mp3`, `.aiff`, `.m4a`
- Özel ses dizini: `~/.notchpilot/sounds/`
- Ses dosyası seçici: macOS standart dosya diyaloğu (NSOpenPanel)

---

## 9. Ayarlar Penceresi

### 9.1 Sekme Yapısı

```
┌─────────────────────────────────────────────────────────────┐
│  ⚙️ NotchPilot Ayarları                                     │
│                                                              │
│  [ Genel ]  [ Görünüm ]  [ Sesler ]  [ Kısayollar ]  [ Hooks ]│
│  ─────────────────────────────────────────────────────────── │
│                                                              │
│  GENEL:                                                      │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ☑ Giriş'te otomatik başlat                            │  │
│  │ ☑ Fullscreen uygulamalarda göster                      │  │
│  │ ☑ macOS bildirimleri gönder                            │  │
│  │                                                        │  │
│  │ Hareketsizlik süresi: [ 15 dakika ▼ ]                 │  │
│  │   (5 / 10 / 15 / 30 dakika)                           │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  GÖRÜNÜM:                                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Tema: ( ) Dark  ( ) Light  (•) System                 │  │
│  │ Accent Renk: [🟠 Turuncu ▼]                           │  │
│  │   (Turuncu / Mavi / Mor / Yeşil / Kırmızı / Özel)    │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  SESLER:                                                     │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ☑ Sesler aktif          Ses seviyesi: [━━━━━━━●━━] 70%│  │
│  │                                                        │  │
│  │ Olay              Aktif   Ses Dosyası                  │  │
│  │ ─────────────────────────────────────────────          │  │
│  │ Oturum Başladı    [☑]    [🔊 Varsayılan] [Değiştir]   │  │
│  │ Oturum Bitti      [☑]    [🔊 Varsayılan] [Değiştir]   │  │
│  │ İzin Bekliyor     [☑]    [🔊 Varsayılan] [Değiştir]   │  │
│  │ Soru Soruldu      [☑]    [🔊 Varsayılan] [Değiştir]   │  │
│  │ Plan Hazır        [☑]    [🔊 Varsayılan] [Değiştir]   │  │
│  │ Görev Tamamlandı  [☑]    [🔊 Varsayılan] [Değiştir]   │  │
│  │ Hata Oluştu       [☑]    [🔊 Varsayılan] [Değiştir]   │  │
│  │ Hareketsiz        [☐]    [🔊 Varsayılan] [Değiştir]   │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  KISAYOLLAR:                                                 │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ İzin Ver:       [⌘Y]     (tıkla ve değiştir)         │  │
│  │ Reddet:         [⌘N]     (tıkla ve değiştir)         │  │
│  │ Seçenek 1:      [⌘1]                                 │  │
│  │ Seçenek 2:      [⌘2]                                 │  │
│  │ Seçenek 3:      [⌘3]                                 │  │
│  │ Panel Aç/Kapat: [⌘⇧P]                                │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  HOOKS:                                                      │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ☑ Claude Code hook'larını otomatik kur                │  │
│  │                                                        │  │
│  │ Durum: ✅ Hook'lar aktif                              │  │
│  │ Dosya: ~/.claude/settings.json                         │  │
│  │                                                        │  │
│  │ [ Hook'ları Yeniden Kur ]  [ Hook'ları Kaldır ]       │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│                                           [ Kapat ]          │
└─────────────────────────────────────────────────────────────┘
```

### 9.2 Veri Depolama

- **Ayarlar:** `UserDefaults` (macOS standart, `@AppStorage` ile SwiftUI entegrasyonu)
- **Özel ses dosyaları:** `~/.notchpilot/sounds/`
- **Hook bridge binary:** `~/.notchpilot/bin/notchpilot-bridge`
- **Socket:** `~/.notchpilot/notchpilot.sock`
- **Log dosyaları:** `~/.notchpilot/logs/`

---

## 10. Menu Bar

### 10.1 Menu Bar Icon

- SF Symbol: `airplane` veya özel notch-şekilli ikon
- Durum göstergesi: ikon rengini aktif oturum durumuna göre değiştir

### 10.2 Menu Bar Dropdown

```
┌──────────────────────────────┐
│ NotchPilot                   │
│ ─────────────────────────── │
│ ● 2 aktif oturum            │
│                              │
│ 🟢 alphaz-flutter    12:34  │
│ 🔵 backend-api        3:21  │
│ ─────────────────────────── │
│ 🔇 Sesi Kapat               │
│ ⚙️ Ayarlar...         ⌘,    │
│ ─────────────────────────── │
│ Çıkış              ⌘Q       │
└──────────────────────────────┘
```

---

## 11. Klavye Kısayolları

| Kısayol | İşlev | Bağlam |
|---------|-------|--------|
| `⌘Y` | İzin ver | Permission panel açıkken |
| `⌘N` | Reddet | Permission panel açıkken |
| `⌘1` / `⌘2` / `⌘3` | Seçenek seç | Soru paneli açıkken |
| `⌘⇧P` | Paneli aç/kapat | Her zaman |
| `⌘,` | Ayarları aç | Her zaman |
| `Escape` | Paneli kapat | Panel açıkken |
| `⌘Return` | Metin gönder | Text field aktifken |

Global kısayollar `CGEvent.tapCreate` veya `MASShortcut` / `KeyboardShortcuts` SPM paketi ile yakalanır.

---

## 12. Dosya Yapısı (Final)

```
NotchPilot/
├── Package.swift                          # SPM bağımlılıkları
├── NotchPilot.xcodeproj
├── NotchPilot/
│   ├── App/
│   │   ├── NotchPilotApp.swift            # @main, WindowGroup + MenuBarExtra
│   │   ├── AppDelegate.swift              # NSPanel lifecycle, global shortcuts
│   │   └── AppState.swift                 # @Observable global app state
│   │
│   ├── UI/
│   │   ├── Notch/
│   │   │   ├── NotchWindow.swift          # NSPanel subclass: non-activating, transparent
│   │   │   ├── NotchWindowController.swift# Pencere pozisyonlama, ignoresMouseEvents toggle
│   │   │   ├── PassThroughHostingView.swift # hitTest() override — panel dışı tıklamalar geçer
│   │   │   ├── NotchContainerView.swift   # State router (compact/expanded/hidden)
│   │   │   ├── NotchShape.swift           # Custom Shape: animasyonlu köşe yarıçapı
│   │   │   ├── CompactView.swift          # Compact state UI
│   │   │   ├── ExpandedOverviewView.swift # Oturum listesi
│   │   │   ├── PermissionView.swift       # İzin onay paneli + diff preview
│   │   │   ├── QuestionView.swift         # Soru yanıtlama paneli
│   │   │   ├── PlanReviewView.swift       # Plan inceleme paneli
│   │   │   └── DiffPreviewView.swift      # Basit diff gösterimi (+ / - satırlar)
│   │   │
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift          # MenuBarExtra içeriği
│   │   │
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift         # Ana ayarlar penceresi
│   │   │   ├── GeneralSettingsTab.swift
│   │   │   ├── AppearanceSettingsTab.swift
│   │   │   ├── SoundsSettingsTab.swift
│   │   │   ├── ShortcutsSettingsTab.swift
│   │   │   └── HooksSettingsTab.swift
│   │   │
│   │   └── Shared/
│   │       ├── StatusDot.swift            # Animasyonlu durum noktası
│   │       ├── SessionCard.swift          # Oturum kartı bileşeni
│   │       └── MarkdownText.swift         # Basit markdown renderer
│   │
│   ├── Core/
│   │   ├── Socket/
│   │   │   ├── SocketServer.swift         # Unix domain socket dinleyici (DispatchSource)
│   │   │   └── JSONLParser.swift          # JSONL encode/decode
│   │   │
│   │   ├── Hooks/
│   │   │   ├── HookInstaller.swift        # Hook kurulum/kaldırma/merge + backup
│   │   │   └── HookConfigMerger.swift     # Akıllı JSON merge logic
│   │   │
│   │   ├── Session/
│   │   │   ├── SessionStore.swift         # Actor-based merkezi state yönetimi
│   │   │   ├── SessionTitleResolver.swift # JSONL dosyalarından başlık okuma
│   │   │   └── ToolUseIdCache.swift       # PreToolUse → PermissionRequest ID korelasyonu
│   │   │
│   │   ├── Sound/
│   │   │   ├── SoundManager.swift         # Ses çalma engine
│   │   │   └── SoundPack.swift            # 8-bit ses tanımları
│   │   │
│   │   ├── Screen/
│   │   │   ├── NotchDetector.swift        # NSScreen extension: notchSize, hasPhysicalNotch
│   │   │   ├── ScreenObserver.swift       # didChangeScreenParametersNotification dinleyici
│   │   │   └── ScreenSelector.swift       # Çoklu monitör: automatic vs specific + persistent ID
│   │   │
│   │   ├── Events/
│   │   │   ├── EventMonitor.swift         # NSEvent global + local monitor wrapper
│   │   │   └── EventMonitors.swift        # Mouse move, mouse down, drag subjects
│   │   │
│   │   └── Settings/
│   │       └── SettingsStore.swift         # @Observable ayarlar modeli
│   │
│   ├── Models/
│   │   ├── Session.swift
│   │   ├── HookEvent.swift
│   │   ├── PermissionEvent.swift
│   │   ├── QuestionEvent.swift
│   │   ├── PlanEvent.swift
│   │   └── DiffPreview.swift
│   │
│   ├── Bridge/
│   │   └── notchpilot-bridge/             # Ayrı Swift CLI target
│   │       ├── main.swift
│   │       ├── SocketClient.swift
│   │       └── EventRouter.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       │   ├── AppIcon.appiconset/
│       │   └── AccentColors/
│       ├── Sounds/
│       │   ├── session-start.wav
│       │   ├── session-end.wav
│       │   ├── permission-needed.wav
│       │   ├── question-asked.wav
│       │   ├── plan-ready.wav
│       │   ├── task-completed.wav
│       │   ├── error.wav
│       │   └── idle.wav
│       └── Localizable.strings            # TR + EN
│
├── NotchPilotTests/
│   └── (V2'de eklenecek)
│
├── .github/
│   └── workflows/
│       └── release.yml                    # Tag push → build → DMG → release
│
├── Makefile                               # build, sign, notarize, dmg komutları
├── README.md
├── LICENSE                                # MIT
└── Caskfile                               # Homebrew Cask formula
```

---

## 13. SPM Bağımlılıkları

```swift
// Package.swift
dependencies: [
    // Global keyboard shortcuts
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),

    // Sparkle auto-update (V1.5'te — V1'de opsiyonel)
    // .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),

    // Launch at login
    .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.0.0"),
]
```

> Minimal bağımlılık prensibi: Sadece gerçekten gerekli olanlar. Markdown parser, diff view gibi şeyler custom yazılacak (basit olacakları için).

---

## 14. CI/CD — GitHub Actions

### 14.1 Tetikleme Kuralı

| Olay | Aksiyon |
|------|---------|
| `push` to `main` | Build + test (sadece doğrulama) |
| `tag` push (`v*`) | Build + sign + notarize + DMG + GitHub Release |

### 14.2 Release Workflow Özeti

```yaml
# .github/workflows/release.yml
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-15
    steps:
      - Checkout
      - Xcode select (16+)
      - Build (xcodebuild archive)
      - Sign (Developer ID Application certificate)
      - Notarize (notarytool)
      - Create DMG (create-dmg veya hdiutil)
      - Upload to GitHub Release
      - Update Homebrew Cask (opsiyonel)
```

### 14.3 Gerekli GitHub Secrets

| Secret | İçerik |
|--------|--------|
| `APPLE_CERTIFICATE_P12` | Developer ID Application sertifikası (base64) |
| `APPLE_CERTIFICATE_PASSWORD` | P12 şifresi |
| `APPLE_ID` | Apple ID e-posta |
| `APPLE_APP_PASSWORD` | App-specific password (notarization için) |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

---

## 15. İlk Çalıştırma Akışı (Onboarding)

```
1. Kullanıcı DMG'yi açar, NotchPilot.app'i Applications'a sürükler
2. İlk açılışta:
   a. macOS izin diyaloğu: "NotchPilot Accessibility erişimi istiyor"
      (global keyboard shortcuts için gerekli)
   b. Hoş geldin ekranı:
      ┌─────────────────────────────────────┐
      │  ✈️ NotchPilot'a Hoş Geldin!        │
      │                                     │
      │  Claude Code hook'larını otomatik    │
      │  kurmak ister misin?                 │
      │                                     │
      │  [ Hayır, elle kuracağım ]  [ Kur ] │
      └─────────────────────────────────────┘
   c. "Kur" seçilirse → akıllı merge ile hook'lar yazılır
   d. Bridge binary ~/.notchpilot/bin/ altına kopyalanır
   e. Socket server başlatılır
   f. Menu bar icon'u görünür
   g. Compact notch paneli gösterilir (demo/boş durumda)
3. Kullanıcı Claude Code başlatır → SessionStart hook tetiklenir → panel canlanır
```

---

## 16. Bilinen Kısıtlamalar & Riskler (V1)

> Claude Island analizi sonrası güncellenmiş risk tablosu. Her riskin nasıl çözüldüğü referanslarla belirtilmiştir.

| Risk | Claude Island Durumu | NotchPilot Çözümü |
|------|---------------------|-------------------|
| Notch boyutu cihaza göre değişir | Çözmüş (`auxiliaryTopLeftArea` + `+4` düzeltme) | Aynı yaklaşım (Bkz. 4.2) |
| Kullanıcının mevcut hook'ları bozulabilir | Akıllı merge var ama **yedek yok** | Akıllı merge + **backup** + hata durumunda geri yükleme (Bkz. 5.2) |
| Bridge socket timeout | 5dk Python timeout + 24h hook timeout | 24h hook timeout + `~/.notchpilot/` güvenli socket + auto-recovery (Bkz. 5.4) |
| Fullscreen apps notch'u gizler | **Çözmemişler** (Issue #41, #55) | Hover trigger zone + izin isteğinde otomatik gösterim (Bkz. 4.5) |
| Çoklu monitör pozisyonlama | Çözmüş (ScreenSelector + persistent ID) | Aynı yaklaşım + harici monitörde **pill bar** (Bkz. 4.2) |
| Accessibility izni gerekli | Kontrol eder ama zorunlu tutmaz | İzinsiz çalışma modu: kısayollar devre dışı, butonlar çalışır (Bkz. 9.1) |
| Python bağımlılığı | Hook script Python 3 gerektirir (Issue #47) | **Swift CLI bridge — sıfır dış bağımlılık** |
| Socket güvenliği | `/tmp/` + `chmod 777` (Issue #48) | `~/.notchpilot/` + `chmod 700` |
| Focus çalma | `.nonactivatingPanel` ile çözmüş | Aynı + selective focus yönetimi (Bkz. 4.1) |
| Hook script üzerine yazma | Her açılışta script silip tekrar kopyalıyor | Bridge versiyon kontrolü: sadece eski versiyonu güncelle |

---

## 17. Lokalizasyon

V1'de iki dil:

| Dil | Dosya |
|-----|-------|
| Turkce (varsayılan) | `tr.lproj/Localizable.strings` |
| English | `en.lproj/Localizable.strings` |

macOS sistem diline göre otomatik seçim.

---

## 18. Performans Hedefleri

| Metrik | Hedef |
|--------|-------|
| RAM kullanımı (idle) | < 30 MB |
| RAM kullanımı (aktif, 5 oturum) | < 50 MB |
| CPU kullanımı (idle) | < 0.1% |
| CPU kullanımı (animasyon) | < 2% |
| Bridge cold start | < 100ms |
| Socket mesaj latency | < 10ms |
| Panel açılma animasyonu | 60 FPS |
| Uygulama başlangıç süresi | < 1 saniye |

---

## 19. Claude Island Karşılaştırma & Fark Analizi

> Claude Island (v1.2, 1626 star) kaynak kodu analiz edilerek oluşturulmuştur.

### Aldığımız Pattern'ler (Kanıtlanmış)

| Pattern | Kaynak | Nerede Kullanıyoruz |
|---------|--------|---------------------|
| `NSPanel` + `ignoresMouseEvents` toggle | `NotchWindow.swift` | Bkz. 4.1 |
| `PassThroughHostingView` (hitTest override) | `NotchViewController.swift` | Bkz. 4.1 |
| Notch boyut hesaplama (`auxiliaryTopLeft/Right` + `+4`) | `Ext+NSScreen.swift` | Bkz. 4.2 |
| `ScreenIdentifier` (persistent monitor ID) | `ScreenSelector.swift` | Bkz. 4.2 |
| `ScreenObserver` (`didChangeScreenParametersNotification`) | `ScreenObserver.swift` | Bkz. 4.2 |
| Tool use ID FIFO cache (PreToolUse → PermissionRequest) | `HookSocketServer.swift` | Bkz. 5.2 |
| 86400s hook timeout for PermissionRequest | `HookInstaller.swift` | Bkz. 5.3 |
| Akıllı hook merge (idempotent append) | `HookInstaller.swift` | Bkz. 5.2 |
| Actor-based `SessionStore` (thread-safe state) | `SessionStore.swift` | Bkz. 7.5 |
| State machine with `canTransition(to:)` | `SessionPhase.swift` | Bkz. 7.1 |
| Spring animation: farklı open/close parametreleri | `NotchView.swift` | Bkz. 4.4 |
| Animasyonlu `NotchShape` (corner radius) | `NotchShape.swift` | Bkz. 4.4 |
| Boot animation (1s expand-collapse) | `NotchViewModel.swift` | Bkz. 4.4 |
| Bounce on complete (150ms) | `NotchViewModel.swift` | Bkz. 4.4 |
| Staggered button reveal (50ms delay) | `NotchView.swift` | Bkz. 4.4 |
| `.mainMenu + 3` window level | `NotchWindow.swift` | Bkz. 4.1 |
| Non-activating + selective focus | `NotchWindow.swift` | Bkz. 4.1 |
| PostToolUse → pending permission iptal | `HookSocketServer.swift` | Bkz. 5.4 |
| Session end → tüm pending temizleme | `HookSocketServer.swift` | Bkz. 5.4 |

### Bizim Fark Yarattığımız Alanlar (Claude Island'da Yok)

| Özellik | Claude Island | NotchPilot |
|---------|--------------|------------|
| Bridge dili | Python 3 (dış bağımlılık, Issue #47) | **Swift CLI** (sıfır bağımlılık) |
| Hook yedekleme | Yok (veri kaybı riski) | **Otomatik backup** + hata durumunda geri yükleme |
| Socket güvenliği | `/tmp/` + `chmod 777` (Issue #48) | **`~/.notchpilot/`** + `chmod 700` |
| Fullscreen desteği | Yok (Issue #41, #55) | **Hover trigger zone** + otomatik gösterim |
| Harici monitör UI | Sahte notch dikdörtgeni | **Pill-shaped floating bar** |
| Klavye kısayolları | Yok (Issue #49) | **Cmd+Y/N/1/2/3** V1'de var |
| Soru yanıtlama | Yok | **Butonlar + text field** V1'de var |
| Plan inceleme | Yok | **Markdown render** V1'de var |
| Ses bildirimleri | Yok | **8-bit sesler** + özel ses desteği |
| Tema seçeneği | Sadece dark | **Dark / Light / System** |
| Gizlilik | Mixpanel + hardware UUID | **Analitik yok** |
| Socket auto-recovery | Yok (restart gerekir) | **Otomatik yeniden oluşturma** |
| Toplu onay | Yok | **"Bu oturumda hep izin ver"** |
| Diff preview | Yok | **Edit/Write için +/- satır gösterimi** |
