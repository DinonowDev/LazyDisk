# راهنمای بنچمارک و تست عملکرد

[English](benchmark-testing-en.md) · فارسی

این سند گام‌به‌گام اندازه‌گیری عملکرد LazyDisk (native + headless)، ساخت گزارش **Markdown/PDF** و مقایسه با **DaisyDisk** روی همان مک را توضیح می‌دهد. مقایسه با DaisyDisk فقط از طریق اسکریپت خودکار است.

## پیش‌نیازها

| ابزار | کاربرد |
|--------|--------|
| Xcode / Swift 5.9+، macOS 13+ | `swift build`, `swift test` |
| Python 3 | گزارش و اتوماسیون DaisyDisk |
| pandoc + BasicTeX | PDF (اختیاری؛ همیشه `.md` ساخته می‌شود) |
| DaisyDisk (برای مقایسه) | `/Applications/DaisyDisk.app` |

نصب یک‌بار برای PDF:

```bash
brew install pandoc basictex
eval "$(/usr/libexec/path_helper)"   # یا ترمینال را ببند و دوباره باز کن
which pdflatex
```

## مسیر پیشنهادی (از اول تا آخر)

از ریشهٔ مخزن:

```bash
cd /path/to/LazyDisk

# ۱) همان پوشه‌ای که هر دو اپ اسکن می‌کنند (اول home — سریع‌تر)
export LAZYDISK_BENCHMARK_ROOT="$HOME"
export LAZYDISK_BENCHMARK_NAV_STEPS=20

# ۲) بنچمارک LazyDisk — روی درخت بزرگ ممکن است چند دقیقه تا بیشتر طول بکشد
./Scripts/benchmark-native-scan.sh "$HOME/Library"

# ۳) یک‌بار: دسترسی Accessibility برای اتوماسیون DaisyDisk
./Scripts/benchmark-daisydisk-auto.sh --check

# ۴) بنچمارک DaisyDisk (باز کردن اپ، rescan، کلیک روی نمودار)
./Scripts/benchmark-daisydisk-auto.sh
# مسیر صریح: ./Scripts/benchmark-daisydisk-auto.sh "$HOME"
```

بعد از اتمام:

- `benchmark-results/latest-report.md` — خلاصهٔ LazyDisk  
- `benchmark-results/report-compare-auto-*.md` (و `.pdf` در صورت pandoc) — مقایسه با DaisyDisk  

همهٔ خروجی‌ها در `benchmark-results/` است (در git نیست).

### دو مسیر مختلف در `benchmark-native-scan.sh`

| تنظیم | معنی |
|--------|------|
| **آرگومان اول** (مثلاً `$HOME/Library`) | **فاز A** — بنچمارک native روی آن پوشه |
| **`LAZYDISK_BENCHMARK_ROOT`** (مثلاً `$HOME`) | **فاز B** — gated ready + ناوبری headless؛ همان `scanRoot` در JSON |

برای مقایسهٔ منصفانه با DaisyDisk، `LAZYDISK_BENCHMARK_ROOT` را همان پوشه‌ای بگذار که در DaisyDisk باز می‌کنی (اغلب `$HOME`). فاز A می‌تواند روی `$HOME/Library` بماند تا native سریع‌تر تمام شود.

## چه چیزهایی اندازه گرفته می‌شود؟

### فاز A — سایز‌گیری native (`LazyDiskFS`)

- تست `NativeScanBenchmarkTests` با walk شبیه `getattrlistbulk`.
- با `LDFS_BENCHMARK=1`, `LDFS_BENCHMARK_PATH` و `BENCHMARK_RUNS` (در اسکریپت فاز A پیش‌فرض **۲** بار اجرا).

### فاز B — gated ready + ناوبری (بدون UI)

شبیه‌سازی مسیر اصلی اپ با `VolumeScanBenchmark`:

1. **`list_volume_root`** — لیست ریشه  
2. **`volume_tree_scan`** — ایندکس عمیق (معمولاً ~۹۵٪ `gatedReadySeconds`)  
3. **`chart_child_map`** — نقشهٔ sunburst  
4. **`prefetch_display_depth`** — prefetch عمق نمایش  
5. **ناوبری** — `LAZYDISK_BENCHMARK_NAV_STEPS` بار لیست پوشه از ایندکس (بدون walk مجدد زیردرخت)

| متغیر | پیش‌فرض | معنی |
|--------|---------|------|
| `LAZYDISK_BENCHMARK_ROOT` | `/System/Volumes/Data` | ریشهٔ اسکن در JSON (`scanRoot`) |
| `LAZYDISK_BENCHMARK_NAV_STEPS` | `20` | قدم drill-down بعد از اسکن |
| `LAZYDISK_BENCHMARK` | توسط اسکریپت | فعال‌کردن `testVolumeScanBenchmarkReport` |

**نکته:** `gatedReadySeconds` headless شامل SwiftUI، انیمیشن splash، کش اپ و Admin Helper نیست؛ زمان واقعی «تا تعاملی شدن» در اپ ممکن است کمی بیشتر باشد.

### فاز C — DaisyDisk (خودکار)

جداگانه با `benchmark-daisydisk-auto.sh` بعد از فاز B — بخش [اتوماسیون DaisyDisk](#اتوماسیون-daisydisk).

## فایل‌های خروجی

### LazyDisk

| فایل | توضیح |
|------|--------|
| `lazydisk-<timestamp>.json` | دادهٔ خام |
| `latest-lazydisk.json` | آخرین اجرای LazyDisk |
| `report-<timestamp>.md` / `.pdf` | گزارش LazyDisk |
| `latest-report.md` / `latest-report.pdf` | آخرین گزارش LazyDisk |

### DaisyDisk

| فایل | توضیح |
|------|--------|
| `daisydisk-auto-<timestamp>.json` | نتیجهٔ خودکار |
| `latest-daisydisk.json` | آخرین DaisyDisk |
| `report-compare-auto-<timestamp>.md` / `.pdf` | گزارش مقایسه |

### فیلدهای مهم JSON

| فیلد | معنی |
|------|------|
| `scanRoot` | پوشهٔ اسکن‌شده |
| `gatedReadySeconds` | زمان «آماده» (LazyDisk: pipeline headless؛ DaisyDisk: heuristic CPU بعد از rescan) |
| `navigationSteps` | تعداد قدم ناوبری |
| `navigationTotalSeconds` / `navigationMedianSeconds` | سرعت ناوبری |
| `phases[]` | فقط LazyDisk — تفکیک فازها |

## اتوماسیون DaisyDisk

DaisyDisk API عمومی ندارد. `benchmark-daisydisk-auto.py` از **Accessibility** و **Automation** استفاده می‌کند.

### دسترسی‌ها (یک‌بار)

macOS این‌ها را خودکار نمی‌دهد.

```bash
./Scripts/benchmark-daisydisk-auto.sh --check
```

تا **`Preflight passed`** ببینی دوباره اجرا کن.

1. **تنظیمات سیستم → حریم خصوصی و امنیت → Accessibility** — Terminal یا Cursor (همان جایی که اسکریپت را می‌زنی) **روشن**.  
2. در صورت پرسش **Automation** — اجازهٔ کنترل **DaisyDisk**.  
3. نصب DaisyDisk در `/Applications/DaisyDisk.app`.

اگر Accessibility نباشد، اسکریپت تنظیمات Privacy را باز می‌کند.

### مراحل اسکریپت

1. `scanRoot` از `latest-lazydisk.json` (یا آرگومان مسیر).  
2. بستن **LazyDisk** در صورت اجرا.  
3. `open -a DaisyDisk <scanRoot>`.  
4. **Action → Rescan Current Folder** (در نسخه‌های دیگر نام منو ممکن است متفاوت باشد؛ fallback در اسکریپت هست).  
5. انتظار تا CPU پروسه‌های DaisyDisk زیر **~۸٪** برای **۸ نمونهٔ پشت‌سرهم** (هر ۰٫۵ ثانیه)، بعد از حداقل **۸ ثانیه** اسکن — حداکثر **۲ ساعت**.  
6. **`LAZYDISK_BENCHMARK_NAV_STEPS`** دوبارکلیک در نقطهٔ ثابت نمودار (~۵۸٪ عرض، ~۵۲٪ ارتفاع پنجره).  
7. JSON، `benchmark-compare.py` و گزارش MD/PDF.

### محدودیت‌ها

| موضوع | توضیح |
|--------|--------|
| پایان اسکن | heuristic CPU با احساس UI یکی نیست؛ ممکن است زود/دیر تمام شود. |
| LazyDisk gated ready | فاز `volume_splash_ready` + نقشهٔ نمودار؛ **بدون** انتظار برای `volume_tree_scan` (اسکن کامل در پس‌زمینه ادامه می‌یابد). |
| ناوبری | کلیک ثابت ≠ مسیر «بزرگ‌ترین فرزند» در harness LazyDisk. |
| Rescan ادمین | در حین بنچمارک **Quick Rescan as Administrator** نزن؛ اسکریپت **Rescan Current Folder** می‌زند. |
| مدت | home اغلب **چند دقیقه**؛ کل volume Data می‌تواند **ساعت‌ها** باشد. |

### چک‌لیست مقایسهٔ منصفانه

- همان مک و دیسک، I/O پس‌زمینه کم  
- همان **`scanRoot`** در هر دو JSON  
- مجوزها / Full Disk Access تا حد ممکن مشابه  
- rescan تازه (اسکریپت خودش rescan می‌زند)  
- همان **`LAZYDISK_BENCHMARK_NAV_STEPS`**  
- **DaisyDisk:** اگر بلافاصله بعد از `benchmark-native-scan.sh` دو بار `benchmark-daisydisk-auto` زدی و اجرای اول «گated ready» غیرعادی طولانی بود (~۱۰۰s+ روی همان `scanRoot`)، آن را در compare نگیر؛ DaisyDisk را quit کن، یک اجرای تمیز بزن و **`latest-daisydisk.json`** همان اجرای معتبر (معمولاً دومی یا اجرای تازه بعد از quit) باشد.

## ساخت مجدد گزارش

فقط LazyDisk:

```bash
python3 Scripts/benchmark-report.py benchmark-results/latest-lazydisk.json \
  --out-dir benchmark-results \
  --basename my-report
```

با DaisyDisk:

```bash
python3 Scripts/benchmark-report.py benchmark-results/latest-lazydisk.json \
  --daisy-json benchmark-results/latest-daisydisk.json \
  --out-dir benchmark-results \
  --basename my-report
```

مقایسه در ترمینال:

```bash
python3 Scripts/benchmark-compare.py \
  benchmark-results/latest-lazydisk.json \
  benchmark-results/latest-daisydisk.json
```

### امتیاز مقایسه (/10)

سه معیار: gated ready، nav total، nav median (کمتر بهتر). اگر یک طرف **۰** باشد، آن ردیف امتیاز **۰** می‌گیرد — `latest-daisydisk.json` با صفر یعنی دوباره `benchmark-daisydisk-auto.sh` بزن. میانگین بالاتر = LazyDisk نزدیک‌تر یا سریع‌تر روی آن معیارها.

## خواندن نتایج LazyDisk

- **`volume_tree_scan`** معمولاً بیشترین سهم را دارد.  
- **ناوبری** جمع ~۰٫۱ ثانیه برای ۲۰ قدم (ایندکس گرم) برای UX بعد از اسکن خوب است.  
- **`volumeTreeFilesScanned`** و **`indexedPathCount`** برای مقایسهٔ ماشین‌ها مفیدند.

تقریب سرعت: `volumeTreeFilesScanned / ثانیهٔ فاز volume_tree_scan`.

## رفع مشکل

| مشکل | کار پیشنهادی |
|------|----------------|
| `No BENCHMARK_JSON line` | از ریشهٔ مخزن اجرا کن؛ `LAZYDISK_BENCHMARK=1` و همان `LAZYDISK_BENCHMARK_ROOT` را تست کن. |
| فاز B خیلی طولانی | اول `$HOME` به‌جای `/System/Volumes/Data`. |
| Accessibility MISSING | Terminal/Cursor در Accessibility؛ `--check` را دوباره بزن. |
| خطای منوی Rescan | اسکریپت به‌روز — **Rescan Current Folder**. |
| امتیاز مقایسه همه ۰ | اعداد DaisyDisk در JSON صفر است — auto را دوباره اجرا کن. |
| PDF نیست | pandoc/basictex؛ `.md` کافی است. |
| پنجرهٔ پسورد ادمین | rescan ادمین را لغو کن؛ از اسکریپت عادی استفاده کن. |

## اسکریپت‌ها

| اسکریپت | نقش |
|---------|-----|
| `Scripts/benchmark-native-scan.sh` | فاز A + B و گزارش LazyDisk |
| `Scripts/benchmark-daisydisk-auto.sh` | فاز C + مقایسه |
| `Scripts/benchmark-report.py` | JSON → MD/PDF |
| `Scripts/benchmark-compare.py` | مقایسه در ترمینال + گزارش |

## تست واحد (مثل CI)

```bash
swift test
```

بدون env، بنچمارک‌ها skip می‌شوند:

```bash
LDFS_BENCHMARK=1 swift test --filter NativeScanBenchmarkTests
LAZYDISK_BENCHMARK=1 LAZYDISK_BENCHMARK_ROOT="$HOME" swift test --filter VolumeScanBenchmarkTests
```

`testNavigationHarnessOnTempTree` همیشه روی درخت کوچک موقت اجرا می‌شود.

## توسعهٔ اپ

```bash
./Scripts/dev.sh
swift test
```

کارهای عمومی: `README.md` و `CONTRIBUTING.md`.
