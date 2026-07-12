# 改善計画: 拡張機能要素の撤去と macOS アプリとしての品質向上 (2026-07-12)

前提: 本プロダクトは **macOS ネイティブアプリ専用** とし、Safari extension としての役目は終了した。
本計画は [2026-07-12-app-review.md](2026-07-12-app-review.md) の指摘を「extension 廃止」を前提に再整理し、4 フェーズに分けたもの。

## 進捗 (2026-07-12 更新)

- [x] Phase 0: extension ファイル削除 (`manifest.json`, `popup.*`, `Passgen Extension/`, `Resources/`)、README 更新
- [ ] Phase 0-3: リポジトリ名変更 (ユーザーの GitHub 操作待ち)
- [x] Phase 1-1: 生成アルゴリズム刷新 (一様構成 + CSPRNG シャッフル + 逐次フォールバック)。統計検証済み (30,000 試行: 頻度 obs/exp ≈ 1.000、位置バイアス解消、必須文字種欠落 0)
- [x] Phase 1-2: クリップボード ConcealedType 併記 + 90 秒自動クリア (changeCount 確認つき)
- [x] Phase 1-3: 結果のマスク表示トグル + 結果クリアボタン
- [x] Phase 1-4: 平文エクスポートの注意喚起 (保存パネル + 保存後ステータス)
- [x] Phase 3-1: 長大結果 (>10,000 文字) の詳細解析スキップ (生成上限 999,999 は維持)
- [x] Phase 3-2: ウィンドウ最小サイズをサイドバー状態と連動 (表示時 1240×760 / 非表示時 980×720)、フレーム自動保存追加
- [x] Phase 3-5: deployment target を 26.2 → 14.0 に変更 (13.0 は 2 引数 `onChange(of:)` が使えずビルド不可のため 14.0 が下限)
- [ ] Phase 2: ファイル分割 + テストターゲット (未着手)
- [ ] Phase 3-3: 強度表示の簡素化判断 (未着手・要設計判断)

extension 廃止により、レビュー指摘のうち以下は **Phase 0 の削除だけで解消 (または失効)** する。

- 1-1 (extension ターゲット不在) / 1-2 (JS/Swift 二重実装) / 1-5 (テンプレート残骸)
- 2-6 (SafariWebExtensionHandler の os_log)
- 3-1, 3-2, 3-5 (popup.js のバグ・脆いヒューリスティック) / 2-7 (popup.js の強度ラベル)
- 4-1〜4-4 の popup 側 UI 指摘

---

## Phase 0: 拡張機能要素の完全撤去

**目的**: リポジトリの名実を「macOS アプリ」に一致させる。コード変更を伴わないため最初に単独で完了させる。

### 0-1. 削除対象ファイル

| パス | 内容 | 削除して安全な根拠 |
|---|---|---|
| `manifest.json` | WebExtension マニフェスト | どのターゲットにも属していない |
| `popup.html` / `popup.js` / `popup.css` | extension ポップアップ一式 | 同上。native アプリから参照なし |
| `xcode/Passgen/Passgen Extension/` (フォルダごと) | `SafariWebExtensionHandler.swift`, `Info.plist` | `project.pbxproj` に extension ターゲット・ファイル参照が存在しない |
| `xcode/Passgen/Passgen/Resources/` (フォルダごと) | `Main.html`, `Script.js`, `Style.css`, `Icon.png`, `Base.lproj/` | extension テンプレートの残骸。pbxproj の Resources build phase は `Main.storyboard` と `Assets.xcassets` のみで、このフォルダは未登録。アプリアイコンは `Assets.xcassets` 側にあるため `Icon.png` 消失の影響なし |

実行コマンド (要承認):

```sh
git rm manifest.json popup.html popup.js popup.css
git rm -r "xcode/Passgen/Passgen Extension" xcode/Passgen/Passgen/Resources
```

削除**しない**もの:

- `NativePasswordGeneratorView.swift` 内の共通単語リストの `"safari"` (弱いパスワード検出用の語彙であり extension とは無関係)
- 設定ストレージキー `nativePassgenSettings` / `nativePassgenPresets` (リネームすると既存ユーザーの設定・プリセットが消える。互換性維持を優先)

### 0-2. ドキュメント更新

- `README.md`: 冒頭に「macOS ネイティブアプリである」ことを明記 (現状も macOS アプリとして書かれているが、リポジトリ名との矛盾を解く一文を追加)。`ファイル構成` から削除ファイルの記述がないことを確認。
- `AGENTS.md`: すでにアプリ前提の内容のため変更ほぼ不要。プロジェクト構成に extension 関連が載っていないことを確認するのみ。
- `docs/` 配下の過去タスク・設計メモは履歴として残す (書き換えない)。

### 0-3. リポジトリ名の変更 (ユーザー作業)

`safari-extension_passgen` → 例: `passgen-macos` / `macos-app_passgen`

これはリポジトリ外・外部サービス操作のため、以下を **ユーザー自身が実行** する。

1. GitHub: Settings → Rename repository (旧名へのアクセスは自動リダイレクトされる)
2. ローカル: `mv ~/github/safari-extension_passgen ~/github/passgen-macos`
3. リモート URL 更新: `git remote set-url origin git@github.com:saito-tk/passgen-macos.git`

補足: Xcode プロジェクト名・アプリ表示名は `Passgen` のままで一貫しており変更不要。

### 0-4. 任意 (Phase 2 と同時でも可): `Native` プレフィックスの整理

`NativePasswordGeneratorView` 等の `Native` は「JS 版と区別する」ための extension 時代の命名。JS 版消滅後は無意味なので、Phase 2 のファイル分割時にまとめてリネームする (`PasswordGeneratorView`, `PasswordSettings`, ...)。Phase 0 では触らない (diff を削除のみに保つ)。

### 完了条件 (DoD)

- `grep -ri "extension\|manifest\|popup" --include="*.swift" --include="*.json"` でヒットするのが savePanel の `isExtensionHidden` と Swift の `extension` 宣言のみ
- Xcode で `Passgen` スキームがクリーンビルド・起動できる
- README がリポジトリの実態と一致

---

## Phase 1: セキュリティ修正 (レビュー High/Medium)

**目的**: 「表示している強度が実態と一致する」「生成物の取り扱いが安全」の 2 点を満たす。

### 1-1. 生成アルゴリズムの刷新 (レビュー 2-1, 2-2)

現行の「プールを一様に選ぶ → プール内文字を選ぶ」二段抽選と、必須文字種の先頭寄せを廃止し、定石構成に置き換える。

1. `requireEachSelectedType` 時: 各プールから 1 文字ずつ確保
2. 残り枠は **全文字セットから文字単位で一様に** 選ぶ
3. 全体を **CSPRNG (SecRandomCopyBytes) による Fisher–Yates** でシャッフル
4. 制約 (先頭文字制限 / `maxConsecutiveRun` / 固定 prefix 直後の連続数) を満たさない場合は**棄却して再生成** (試行上限つき。上限到達時は現行同様のエラー)
5. `completeUniform` モードは現行実装 (正しい) を維持

エントロピー表示も新方式に合わせて再導出する。一様充填 + シャッフル方式なら `length × log2(charsetSize)` が (制約による微小な減少を除き) 正当化される。`maxConsecutiveRun` 等の制約による減少分は「上限値の目安」であることを help に明記。

**検証**: 統計テストを同時に導入する (Phase 2 のテスト基盤を先取りしてこの項だけ先に作ってよい)。
- 文字ごとの出現頻度の χ² 検定 (completeUniform / 通常モード両方)
- 位置ごとの文字種分布が一様であること (先頭寄せ解消の確認)

### 1-2. クリップボード保護 (レビュー 2-3)

- `copyToPasteboard` で `org.nspasteboard.ConcealedType` を併記し、クリップボード履歴アプリ・Universal Clipboard への残留/同期を抑止
- コピーから 90 秒後の自動クリア。実装時は書き込み時の `changeCount` を保持し、**一致する場合のみ** クリア (ユーザーが別の物をコピーしていたら消さない)
- 自動クリアの有無は設定ウィンドウで切り替え可能にする (デフォルト ON)

### 1-3. 結果表示の保護 (レビュー 2-4)

- 生成結果一覧にマスク表示トグル (●●● ⇄ 平文) を追加。デフォルトは平文でよいが、状態を設定として記憶
- 「結果をクリア」ボタンを追加 (`results` / `generatedPasswordStore` / `copiedPasswordIDs` を破棄)

### 1-4. 平文エクスポートの告知 (レビュー 2-5)

`exportResultsAsText` の保存パネル message に「パスワードは暗号化されない平文で保存されます」を追記し、保存成功後のステータスにも同旨を一度表示する。

### 完了条件 (DoD)

- 統計テストが通る (頻度・位置分布)
- コピー後にクリップボード履歴アプリ (例: Maccy) へ残らないことを手動確認
- 自動クリアが 90 秒後に発火し、他アプリのコピーを巻き込まないことを確認

---

## Phase 2: 構造改善 (レビュー 1-3, 1-4)

**目的**: 生成エンジンを View から切り離してテスト可能にする。

### 2-1. ファイル分割 (6,120 行 → 責務別)

| 新ファイル | 移動する内容 |
|---|---|
| `PasswordGenerator.swift` | `createPassword` / `createUniformPassword` / `randomInt` / プール構築 / エントロピー計算 |
| `PasswordAnalysis.swift` | 強度評価・blocklist・パターン検出一式 |
| `PresetStore.swift` | プリセットの保存/復元/import/export/検証 |
| `PasswordModels.swift` | `NativePasswordSettings` ほか Codable モデル群 |
| `PasswordGeneratorViewModel.swift` | ViewModel |
| `Views/` 配下数ファイル | SwiftUI View 群 (カード単位) |

このタイミングで 0-4 の `Native` プレフィックス除去と、`applying(to:)` の手動 20 項目代入の構造見直し (レビュー 3-6) も行う。**動作を変えない純粋なリファクタリングとして 1 コミットにまとめず、ファイル移動→リネーム→構造変更の順で分割コミット**する。

### 2-2. テストターゲット追加

`PassgenTests` を新設し、最低限以下を固定する。

- `randomInt(upperBound:)`: 境界 (1, 2, 2^n, 2^n±1) と分布
- 生成結果の性質検査: 長さ / 必須文字種の包含 / `maxConsecutiveRun` 順守 / 先頭文字制限順守 / 固定 prefix
- Phase 1-1 の統計テスト (頻度 χ² / 位置分布)
- `validateSettings` の全分岐
- `decodePresetExportDocument`: 正常系 + 不正 JSON 系列 (型違い / 配列長違い / バージョン違い / boolean を数値で偽装)
- `normalizedSettings(from:)` のクランプ
- 全角数字正規化 / 数値補正メッセージ

### 完了条件 (DoD)

- 全テストがローカルで通る
- `NativePasswordGeneratorView.swift` (改名後) が View 定義のみ・1,000 行未満

---

## Phase 3: UX / 仕様整理 (レビュー Medium/Low)

優先度は Phase 1・2 より下。個別に着手可能。

1. **文字数上限 999,999 は維持する (製品判断・確定)**: レビュー 3-3 は「上限を下げる」提案だったが、**超長文字列を生成できることこそ本アプリの存在理由** (既存ツールの文字数上限が厳しくて生成できない悩みを解決するために作られた) のため採用しない。文字数の使い道はユーザーの自由であり、システム側でガードレールを狭めない。連動する件数上限式も総生成量の予算として現状維持。代わりに副作用のみ手当てする。
   - 強度解析の計算量対策: パターン検出 (繰り返しブロック・キーボード配列等) は一定長 (例: 10,000 文字) を超える結果ではスキップし、「長大なため詳細解析は省略 (エントロピー評価のみ)」と注記する。生成の自由は制限せず、解析だけ軽くする
   - README にこの設計思想 (超長パスワード生成が第一級ユースケースであること) を明記し、将来のリファクタリングで上限が「整理」されないよう仕様として固定する
2. **ウィンドウ最小サイズ** (4-5): 1380×840 固定をやめ、サイドバー非表示時は縮められるようにする
3. **強度表示の整理** (4-6): 生成器自身の出力への S/A 評価は情報過多。「エントロピー + 文字セットの広さ」中心へ簡素化するか、現状維持かを設計判断として決める (docs/design に判断メモを残す)
4. **`(0/0)` の初期表示抑制** (4-3)
5. **`MACOSX_DEPLOYMENT_TARGET = 26.2` の見直し** (3-4): 意図的なら `#available` 分岐の削除、そうでなければターゲットを下げる

---

## 実施順序と依存関係

```
Phase 0 (削除・改名)  ← 依存なし。最初に単独コミット
   ↓
Phase 1-1 (生成刷新) ←→ Phase 2-2 の統計テスト (同時に作る)
Phase 1-2〜1-4 (クリップボード/マスク/告知) ← 依存なし、いつでも可
   ↓
Phase 2 (分割 + テスト全量)
   ↓
Phase 3 (UX 整理)
```

- Phase 0 は削除のみで独立しており、レビュー指摘の約 4 割がここで解消する。**最優先で実施**。
- Phase 1-1 は挙動が変わる (同じ設定でも出力分布が変わる) ため、README の生成仕様記述の更新と、リリースノートでの言及をセットにする。
- リポジトリ名変更 (0-3) はユーザーの GitHub 操作が必要。Phase 0 のファイル削除とは独立に、任意のタイミングで実施できる。
