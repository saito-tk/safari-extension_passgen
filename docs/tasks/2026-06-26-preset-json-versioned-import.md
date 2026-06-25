# プリセットJSON バージョン別 import 実装タスク

## 背景

プリセット export JSON は今後形式が変わる可能性がある。アプリ側で現在の JSON 形式だけを直接検証すると、将来の変更時に過去 JSON の import が壊れやすい。形式バージョンを判定し、version ごとの読み込み処理を保持する。

## タスク

- [x] `docs/design/preset-saving.md` に JSON version ごとの import 方針を追加する。
- [ ] import 処理を JSON version 判定と version 別 decoder に分離する。
- [ ] 現行形式を `version = 1` として扱う。
- [ ] `format` または `version` が欠落している旧JSON候補を version 1 として正規化する。
- [ ] 旧JSON候補でもプリセット/設定値が不正な場合は import しない。
- [ ] Xcode build で確認する。

## 確認観点

- 現行 export JSON は従来どおり import できる。
- `format` が欠落していても、version 1 相当の `presets` 配列を持つ JSON は import できる。
- `version` が欠落していても、version 1 相当の `presets` 配列を持つ JSON は import できる。
- 対応していない version は import できない。
- 不正な旧JSON候補は import されない。
