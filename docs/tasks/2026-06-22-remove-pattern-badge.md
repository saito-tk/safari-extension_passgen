# Pattern バッジ削除 実装タスク

## 対応仕様

- `docs/design/password-strength-analysis.md`

## 目的

生成結果行の `Pattern` バッジを削除し、通常時に情報量の薄い指標を表示しないようにする。

## 作業タスク

- [ ] 生成結果行から `Pattern` バッジを削除する。
- [ ] パターン検出ロジックと補助メッセージ表示は維持する。
- [ ] `xcodebuild -project xcode/Passgen/Passgen.xcodeproj -scheme Passgen -configuration Debug build` で確認する。

## 完了条件

- 生成結果行には `Variety` と `Balance` が表示される。
- `Pattern` バッジは表示されない。
- 推測されやすいパターンが検出された場合は、補助メッセージに理由が表示される。
