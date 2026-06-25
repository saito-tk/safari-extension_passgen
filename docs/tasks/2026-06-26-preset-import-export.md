# プリセット import/export 実装タスク

## 背景

保存済みプリセットを別環境へ移したり、バックアップできるようにしたい。export では複数プリセットを選んで JSON として保存し、import では JSON の形式を検証して保存済みプリセットへ追加する。

## タスク

- [x] `docs/design/preset-saving.md` にプリセット import/export 仕様を追加する。
- [x] `README.md` と tips 仕様に import/export の説明を追加する。
- [x] プリセット export 用の複数選択 UI を追加する。
- [x] 選択したプリセットを `.json` として保存する。
- [x] export JSON の外形を `format` / `version` / `exportedAt` / `presets` に固定する。
- [x] import 用の JSON 読み込みを追加する。
- [x] import JSON の外形、必須キー、UUID、日時、設定値を検証する。
- [x] 不正 JSON の場合は 1 件も import しない。
- [x] 重複 UUID がある場合は、別名 import するか確認する。
- [x] 別名 import 時は UUID を再発行し、名前を既存名と衝突しないものにする。
- [x] import 後にプリセット一覧を永続化する。
- [x] Xcode build で確認する。

## 確認観点

- 複数プリセットを選択して JSON export できる。
- export した JSON を import するとプリセット一覧に追加される。
- 既存 UUID と重複する JSON を import すると警告が出る。
- 別名 import を選ぶと UUID が再発行され、名前も別名になる。
- 不正な JSON や必須項目欠落の JSON は import されない。
- import 失敗時は既存プリセット一覧が変化しない。
