# パスワード強度の多軸グレード表示 実装タスク

## 対応仕様

- `docs/design/password-strength-analysis.md`

## 目的

`Basic` / `Good` / `Strong` / `Very Strong` や `Variety` / `Balance` バッジを見直し、NIST/OWASP の考え方を踏まえた S-F の多軸評価へ置き換える。

## 作業タスク

- [x] 既存の強度表示から `Basic` / `Good` / `Strong` / `Very Strong` 前提を外す。
- [x] `Variety` / `Balance` バッジをユーザー向け表示から削除する。
- [x] `長さ`、`総当たり耐性`、`文字の広さ`、`既知リスク`、`推測されにくさ` の各グレードを計算する。
- [x] 各軸のグレードから `総合評価` を計算する。
- [x] 総合評価と各軸の S-F グレードを結果行に表示する。
- [x] 重要度の高い補助メッセージを 2-3 件に絞って表示する。
- [x] README の強度表示説明を更新する。
- [x] `xcodebuild -project xcode/Passgen/Passgen.xcodeproj -scheme Passgen -configuration Debug build` で確認する。

## 完了条件

- 4 文字など短い生成結果が安易に高評価にならない。
- 評価の理由が日本語の軸名と補助メッセージで分かる。
- 文字種の混在を必須条件として扱わず、長さ・entropy・既知リスク・推測されにくさを中心に評価される。
