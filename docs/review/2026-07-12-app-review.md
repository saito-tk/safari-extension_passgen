# アプリ全体レビュー (2026-07-12)

対象: リポジトリ全体 (Web extension 側 `popup.*` / `manifest.json`、native macOS アプリ `xcode/Passgen/`)
観点: アーキテクチャ / セキュリティ (パスワード生成品質) / 実装 / UI・UX / ドキュメント整合性
方針: 厳しめ。重大度は `Critical` / `High` / `Medium` / `Low` の 4 段階。

---

## 総評

パスワード生成の乱数源は JS 側 (`crypto.getRandomValues` + 棄却サンプリング) も Swift 側 (`SecRandomCopyBytes` + 棄却サンプリング) も正しく、modulo bias 対策も両方できている。この基礎部分は合格。

一方で、以下の 3 点は構造的な問題として重い。

1. **Safari extension が実際にはビルドされていない**。リポジトリ名と `manifest.json` に反して、Xcode プロジェクトに extension ターゲットが存在しない。
2. **「ルール優先」生成モードの文字分布が一様でなく、表示している推定エントロピーが実態より過大**。セキュリティツールとして最も誠実であるべき数値が誇張されている。
3. **同一ドメインのロジックが JS と Swift に二重実装され、すでに大きく乖離している**。セキュリティ修正を常に 2 箇所へ適用する必要がある構造で、片側 (JS) はすでに機能面・品質面で置き去りになっている。

加えて、**テストが 1 本も存在しない**。棄却サンプリング、バリデーション、プリセット import の検証ロジックなど、テストで守るべき箇所が多いアプリでこれは看過できない。

---

## 1. アーキテクチャ

### 1-1. [Critical] Safari extension ターゲットが Xcode プロジェクトに存在しない

`Passgen.xcodeproj/project.pbxproj` には native target が **`Passgen` (macOS app) の 1 つしかない**。Resources build phase に含まれるのは `Main.storyboard` と `Assets.xcassets` のみで、以下はどのターゲットにも属していない。

- リポジトリ直下の `manifest.json` / `popup.html` / `popup.js` / `popup.css`
- `xcode/Passgen/Passgen Extension/SafariWebExtensionHandler.swift` と同 `Info.plist`

つまり「Safari 向けのパスワードジェネレータ拡張」と名乗りながら、**成果物は native macOS アプリだけで、extension は配布物に含まれない**。extension を復活させるなら appex ターゲットを追加して popup 一式を Resources に入れる。extension を捨てて native アプリ専用にしたなら、`manifest.json`・`popup.*`・`Passgen Extension/` を削除し、リポジトリの説明も改めるべき。中途半端な現状が一番悪い。

### 1-2. [High] JS / Swift の二重実装がすでに乖離している

同じ「パスワード生成」ドメインが `popup.js` (860 行) と `NativePasswordGeneratorView.swift` (6,120 行) に別々に実装されており、仕様がすでに食い違っている。

| 項目 | popup.js | Swift native |
|---|---|---|
| 生成件数上限 | 30 | 1,000 |
| プリセット | なし | あり (lock / import / export / 並べ替え) |
| 先頭文字ルール / 固定 prefix | なし | あり |
| 同一文字連続 | 連続禁止 on/off のみ | 最大連続数 (0〜99) |
| 強度表示 | Basic〜Very Strong の 4 段階 (独自減点) | S〜F の 6 段階 + blocklist + パターン検出 |
| 必須文字種の選択バイアス | 55% の重み付け | maxGap ベースの決定的選択 |
| テーマ | 7 色 | 13 色 |

「同じ設定なら同じ品質のパスワードが出る」ことすら保証されない。生成コアだけでも仕様を一本化し、どちらかを正とすること。1-1 で extension を廃止するなら JS 側は丸ごと削除できる。

### 1-3. [High] 6,120 行の単一 Swift ファイル

[NativePasswordGeneratorView.swift](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift) に View、ViewModel、設定モデル、プリセット import 検証、生成エンジン、強度解析、blocklist、ユーティリティのすべてが同居している。責務ごとの分割 (最低でも `PasswordGenerator` / `PasswordAnalysis` / `PresetStore` / View 群) は必須。生成エンジンが View ファイルの private static メソッドである限り、単体テストも書けない (→ 1-4)。

### 1-4. [High] テストがゼロ

テストターゲットが存在しない。最低限、次はユニットテストで固定すべき。

- `randomInt(upperBound:)` の棄却サンプリング境界 (upperBound = 1, 2^n, 2^n±1)
- `validateSettings` の全分岐 (fixedPrefix × maxConsecutiveRun × requireEachSelectedType の組合せ)
- `decodePresetExportDocument` の不正 JSON 系列 (型違い / 配列長違い / バージョン違い)
- `normalizedSettings(from:)` のクランプ
- 生成結果の性質検査 (長さ、文字種包含、連続数制限、先頭文字制限を満たすか)
- 分布の χ² 検定程度の統計テスト (completeUniform モード)

### 1-5. [Low] テンプレート残骸

`Resources/Base.lproj/Main.html` / `Script.js` / `Style.css` / `Icon.png` は Safari extension テンプレートの残骸で、現行 UI (SwiftUI) からは未使用。`SafariWebExtensionHandler.swift` もテンプレートの echo 実装のまま。使わないなら削除する。

---

## 2. セキュリティ (パスワード生成品質)

### 2-1. [High] 「ルール優先」モードは一様分布でなく、表示エントロピーが過大

Swift の rule-priority 生成 ([NativePasswordGeneratorView.swift:3248](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift#L3248)) と JS の生成 ([popup.js:613](popup.js#L613)) はいずれも「プールを一様に選ぶ → プール内の文字を一様に選ぶ」二段抽選。プールサイズが違う (数字 10 vs 小文字 26 など) ため、**小さいプールの文字が 1 文字あたり最大 2.6 倍出やすい**。それにもかかわらず、推定エントロピーは `length × log2(全文字セット数)` ([同:3378](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift#L3378), [popup.js:706](popup.js#L706)) で計算しており、**実際の分布に対する min-entropy を上回る値をユーザーに表示している**。

デフォルト設定 (4 プール、計 84 文字前後) では 1 文字あたり実効 6.0 bit 程度 vs 表示 6.4 bit 程度で、16 文字なら 6〜7 bit の過大表示になる。パスワード生成器で「推定 xx bits」と表示する以上、この誇張は許容すべきでない。対応案:

- 二段抽選をやめ、文字単位で一様に選ぶ (completeUniform と同じ抽選) 方式へ寄せる
- どうしても二段抽選を残すなら、エントロピーを実分布 (Σ p·log2 p ではなく保守的に min-entropy) で計算する

### 2-2. [High] 必須文字種の充足が「先頭寄せ」で、構造が予測可能。シャッフルがない

- JS ([popup.js:653](popup.js#L653)): 未充足プールを **55% の固定重み**で優先。先頭 4 文字前後が「各文字種 1 つずつ」になる確率が大きく偏る。
- Swift ([NativePasswordGeneratorView.swift:3518](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift#L3518)): `requireEachSelectedType` 時、未充足プールがあれば **必ず** そこから選ぶ (maxGap フィルタ)。つまり**先頭 N 文字 (N = プール数) は各文字種から 1 つずつ、ほぼ決まった順序構造で出る**。

生成後に **CSPRNG による Fisher–Yates シャッフルを一度もかけていない** ため、この位置バイアスがそのまま出力に残る。「必須文字を先に確保 → 残りを一様に充填 → 全体をシャッフル」が定石であり、そうすればエントロピー計算も単純化する。なお `maxConsecutiveRun` / 先頭文字制限との両立はシャッフル後の再試行 (棄却) で実装できる。

### 2-3. [Medium] クリップボード対策が不足 (concealed / 自動クリアなし)

[copyToPasteboard (6052)](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift#L6052) は `NSPasteboard.general.setString` するだけ。

- `org.nspasteboard.ConcealedType` を併記していないため、**クリップボード履歴アプリや Universal Clipboard にパスワードが平文で残る・同期される**。
- 一定時間 (例: 60〜90 秒) 後の自動クリア (自分が書いた changeCount のときのみ) もない。

パスワードマネージャ相当の慣行としてどちらも実装すべき。JS 側 (`navigator.clipboard`) も同様にクリアがない。

### 2-4. [Medium] 生成結果が常時平文表示で、マスク・一括非表示手段がない

生成結果一覧は全件平文で並び、マスク表示 (●●●) への切り替えや「結果をクリア」ボタンがない (`SecureField` / マスク処理は Swift 側に存在しない)。画面共有・肩越し閲覧の場面を考えると、**デフォルトマスク + ホバー/クリックで表示** か、最低でも表示切り替えトグルは必要。生成した全パスワードは `generatedPasswordStore` にウィンドウを閉じるまで保持され続ける点も含め、「見せ続ける・持ち続ける」設計を見直すこと。

### 2-5. [Medium] テキスト出力が平文ファイルであることの警告がない

`exportResultsAsText` ([2515](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift#L2515)) は全パスワードを平文 `.txt` で書き出す。機能自体は要件だとしても、保存パネルの message が「テキストファイルとして保存します」だけで、**平文保存のリスク告知が一切ない**。保存後ステータスにも注意書きを出すべき。

### 2-6. [Low] SafariWebExtensionHandler が受信メッセージを unified log に出力

[SafariWebExtensionHandler.swift:30](xcode/Passgen/Passgen Extension/SafariWebExtensionHandler.swift#L30) は `os_log(.default, "... %@", String(describing: message))` で **メッセージ内容をそのままログに書く**。現状は未使用のテンプレートだが、将来ここにパスワードや設定を流すと unified log に平文で残る。使う予定がないなら削除、使うなら `%{private}@` にする。

### 2-7. [Low] popup.js の強度ラベルが恣意的

[getStrengthLabel (807)](popup.js#L807) は uniqueCoverage による独自減点で、CSPRNG が正しく生成したパスワードでも文字の偶然の重複で「Strong → Good」に落ちる。統計的根拠がなく、隣に表示するエントロピー値と矛盾したメッセージになる。native 側の S〜F 評価と二重基準になっている点も含め、廃止して native の基準に合わせるべき (1-2 参照)。

### 2-8. 良い点 (維持すること)

- `randomInt` は JS/Swift とも棄却サンプリングで modulo bias なし ([popup.js:690](popup.js#L690), [NativePasswordGeneratorView.swift:3599](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift#L3599))
- `SecRandomCopyBytes` の戻り値検査あり
- completeUniform モードは正しく一様
- 固定 prefix をエントロピーに算入しない (既知前提) 判断は正しい
- App Sandbox / Hardened Runtime 有効
- `manifest.json` の permission は `storage` のみで最小
- プリセット JSON import の型・配列長・バージョン検証は丁寧 (`validatePresetExportObject` 一式)
- 強度解析をローカル完結にし、README で「漏洩 DB 照合ではない」と明記している誠実さ

---

## 3. 実装

### 3-1. [High] popup.js: `storageArea` が null のとき `readSettings` が TypeError で初期化が死ぬ

[popup.js:49](popup.js#L49) で `storageArea` は `null` になり得るが、[readSettings (421)](popup.js#L421) は `if (typeof storageArea.get === "function")` と **null ガードなしでプロパティアクセス**しており、extension ランタイム外 (`applyHostMode` が想定している "app" モード) では即 TypeError。`DOMContentLoaded` ハンドラ内の `await loadSettings(elements)` が reject し、後続の `toggleSymbolsPanel` / `normalizeNumericInputs` / `switchTab` が実行されず **UI が初期化途中で止まる**。`writeSettings` ([450](popup.js#L450)) は `storageArea &&` でガードしているので、非対称なバグ。localStorage フォールバックを実装した意味が失われている。

### 3-2. [Medium] `storageArea.get.length <= 1` による API 判別が脆い

[popup.js:424, 452](popup.js#L424): 関数の `length` (仮引数の個数) で Promise 型か callback 型かを判別している。bind やラッパで簡単に壊れるヒューリスティック。`browser` 名前空間なら Promise、`chrome` なら callback、と名前空間で分岐するのが確実。

### 3-3. [Medium] 文字数上限 999,999 は実害のある設計

- 999,999 文字のパスワードに実用性はなく、強度解析 (`getPasswordPatternFindings` の繰り返しブロック検出など) は長大入力で計算量が跳ねる。JS 側はポップアップの単一スレッドで生成+解析するため、yield を入れていても実質フリーズに近い体験になる。
- `getMaxCountForLength` による「件数上限が文字数に連動して下がる」仕様は、README に式まで書いて説明が必要になっている時点で複雑すぎるサイン。

上限を現実的な値 (例: 512 or 1,024) に下げれば、連動上限も補正警告メッセージ群も丸ごと削除できる。

### 3-4. [Medium] `MACOSX_DEPLOYMENT_TARGET = 26.2`

リリース当時の最新 OS のみ対象で、`#available(iOS 15.0, macOS 11.0, *)` 分岐 (SafariWebExtensionHandler) が全部デッドコードになっている。意図的に最新限定なら constants を整理、そうでないなら下げる。

### 3-5. [Low] popup.js の細かい点

- [copyToClipboard (845)](popup.js#L845) のフォールバックが deprecated な `document.execCommand("copy")`。extension 内なら `navigator.clipboard` は常時使えるので、フォールバックごと削除してよい。
- [generateAndRenderPasswords (521)](popup.js#L521) 末尾の `void writeSettings(settings)`: 設定変更時に毎回 persist しているので二重保存。
- ストレージから読んだ `settings` の型検証がない (boolean 以外が入っても素通り)。Swift 側が `normalizedSettings` で丁寧にクランプしているのと対照的。

### 3-6. [Low] `syncCategorySelectionFlags` の空行 / applying(to:) の全項目手動コピー

[2807](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift#L2807) の関数末尾に不要な空行。`applying(to:)` ([4081](xcode/Passgen/Passgen/NativePasswordGeneratorView.swift#L4081)) は 20 項目超の手動代入で、設定項目追加時に代入漏れしても型エラーにならない。プリセット設定を `NativePasswordSettings` の部分集合構造体として持ち、丸ごと代入できる形にした方が安全。

---

## 4. UI / UX

### 4-1. [Medium] popup のアクセシビリティ不足

- タブ ([popup.html:31](popup.html#L31)) が `role="tablist"` / `role="tab"` / `aria-selected` / `aria-controls` なしの素の button。スクリーンリーダーにはタブとして伝わらない。
- 「Copied!」表示 ([popup.html:146](popup.html#L146)) の `.copy-status` に `aria-live` がなく、コピー成功が読み上げられない。
- 記号チップ ([popup.js:113](popup.js#L113)) のラベルが `title` 属性頼み。`aria-label` を付けるべき。
- テーマスウォッチは色のみの区別 (aria-label はある)。選択状態の視覚表現が色依存。

### 4-2. [Medium] popup にダークモード対応がない

`popup.css` に `prefers-color-scheme` が 1 箇所もない。native アプリは Light/Dark/System を切り替えられるのに、extension 側はライト固定。Safari のダーク環境でポップアップだけ眩しい。

### 4-3. [Low] 初期表示の `(0/0)`

生成前から見出しに `(0/0)` が出る ([popup.js:66](popup.js#L66)、native も同様の progress 表示)。未生成時は非表示にする方が自然。

### 4-4. [Low] バリデーションエラー時に既存の結果を消す

[popup.js:483](popup.js#L483): 設定エラーで生成できなかったとき、前回の生成結果まで `innerHTML = ""` で消す。エラーで何も生成していないのに成果物を失うのはユーザーに不利益。結果は生成成功時のみ置き換えるべき。

### 4-5. [Low] native: ウィンドウ最小サイズ 1380×840 固定

[ViewController.swift:15](xcode/Passgen/Passgen/ViewController.swift#L15) で `minSize` = 1380×840。13" ノート (実効 1280〜1440pt 幅) では画面ほぼ全占有で、縮小の余地がない。サイドバー非表示時は最小幅を下げるなど、レイアウトメトリクスと連動させるべき。

### 4-6. [Low] 強度表示が「生成した本人への評価」としてほぼ無意味

生成器自身が CSPRNG で作った結果に S/A 評価や blocklist 照合を出しても、実際にはほぼ常に高評価で、警告系 (既知リスク/パターン) は固定 prefix 使用時以外まず発火しない。手入力パスワードの評価機能があるなら価値があるが、現状は情報量の割に UI 面積と実装 (数百行の解析コード) を消費している。「評価」ではなく「この設定の生成空間の広さ」(エントロピーと文字セット) に情報を絞る方が UI としては誠実で軽い。

---

## 5. ドキュメント整合性

- [README.md](README.md) は native アプリの仕様書としては充実しているが、冒頭で extension に触れず、`manifest.json` は「Safari 向け拡張」と自称しており、1-1 の混乱をそのまま反映している。プロダクトの実態 (native アプリ / extension は未ビルド) を README 冒頭で明言すべき。
- README の「暗号学的に安全な乱数を使ったパスワード生成」は乱数源としては正しいが、2-1/2-2 のバイアスがある限り「一様なランダム生成」とは言えない。修正までは表現に注意。
- テーマ一覧 (README: 13 色) と popup (7 色) の乖離も 1-2 の症状。

---

## 対応優先度まとめ

| # | 重大度 | 内容 |
|---|---|---|
| 1-1 | Critical | extension ターゲット不在。ビルドに含めるか、extension 一式を削除して名実を一致させる |
| 2-1 | High | ルール優先モードの分布バイアスとエントロピー過大表示の解消 |
| 2-2 | High | 必須文字種の先頭寄せ解消 (生成後の CSPRNG シャッフル導入) |
| 1-2 | High | JS/Swift 二重実装の解消 (extension 廃止なら JS 削除で完了) |
| 1-3 | High | 6,120 行ファイルの分割 (生成エンジンの独立 = テスト可能化) |
| 1-4 | High | テスト導入 (棄却サンプリング / バリデーション / import 検証 / 生成結果性質) |
| 3-1 | High | popup.js `readSettings` の null クラッシュ修正 |
| 2-3 | Medium | クリップボード concealed 指定 + 自動クリア |
| 2-4 | Medium | 結果のマスク表示 / クリア手段 |
| 2-5 | Medium | 平文テキスト出力のリスク告知 |
| 3-3 | Medium | 文字数上限 999,999 の見直し |
| 4-1 | Medium | popup の ARIA 対応 |
| 4-2 | Medium | popup のダークモード対応 |
| その他 | Low | 2-6, 2-7, 3-2, 3-4〜3-6, 4-3〜4-6, テンプレート残骸削除 (1-5) |
