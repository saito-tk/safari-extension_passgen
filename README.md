# Passgen for Safari

Safari 向けのパスワードジェネレータ拡張です。`popup.html` からパスワードの条件を指定し、複数件まとめて生成できます。

## 実装内容

- `crypto.getRandomValues` を使った乱数生成
- 大文字・小文字・数字・記号の個別選択
- 類似文字の除外
- 同一文字の連続禁止
- Safari / Chrome 系の `storage.local` による設定保持
- 生成結果のワンクリックコピー

## ファイル構成

- `manifest.json`
- `popup.html`
- `popup.css`
- `popup.js`

## Safari で使う流れ

1. このディレクトリを Safari Web Extension の元ファイルとして使います。
2. macOS の Safari Web Extension 変換フローで Xcode プロジェクト化します。
3. Xcode から拡張を実行し、Safari の拡張機能設定で有効化します。

Safari Web Extension は WebExtension ベースなので、まずこの構成で UI とロジックを固めてから Xcode 側へ載せる流れにしています。
