# パスワード強度のパターン評価 実装タスク

## 対応仕様

- `docs/design/password-strength-analysis.md`

## 目的

生成結果の強度表示に、`zxcvbn` の考え方に沿った推測されやすいパターン評価を追加する。

## 作業タスク

- [x] 既存の entropy、variety、balance 評価を維持する。
- [x] よく使われる単語、連続文字列、キーボード配列、繰り返し、日付らしい数値列を検出する。
- [x] 検出したパターンを強度スコアへ反映する。
- [x] パターン検出による減点の目安を `Pattern` 指標として表示する。
- [x] 検出したパターンを補助メッセージへ表示する。
- [x] README の強度表示説明を更新する。
- [x] `xcodebuild -project xcode/Passgen/Passgen.xcodeproj -scheme Passgen -configuration Debug build` で確認する。

## 完了条件

- 推測されやすいパターンを含む生成結果では、従来より弱めの評価になる。
- パターンが検出された場合、補助メッセージに理由が表示される。
- 既存の生成処理、コピー、テキスト出力の挙動は変わらない。
