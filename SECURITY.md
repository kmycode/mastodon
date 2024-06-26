# セキュリティポリシー

kmyblueのプログラムにおいてセキュリティインシデントを発見した場合、kmyblueに報告してください。

kmyblueにセキュリティインシデントを報告する場合、以下の手順を踏んでください。

- [こちらのリンクから新規インシデントを起票してください](https://github.com/kmycode/mastodon/security/advisories/new)
- メール <tt@kmycode.net>、または[@askyq@kmy.blue](https://kmy.blue/@askyq)宛に、**セキュリティインシデントを起票したことだけ**を連絡してください。セキュリティインシデントの内容は、絶対に連絡に含めないでください（リンクくらいなら含めていいかな）

他のkmyblueフォークの利用者の安全のために少しでも時間稼ぎをしなければいけないので、この問題をIssueを含む公開された場所で記述しないでください。

## 範囲

こちらが対応できる範囲は、当リポジトリで公開しているソースコードのみとなります。当リポジトリの依存パッケージ内に問題がある場合は、そちらに報告してください。

もしあなたに専門知識があり、それが本家Mastodon由来の問題であると信じるに足る根拠がある場合、kmyblueではなくMastodonのほうに報告してください。kmyblueに報告されても、Mastodonより先に修正してしまうことでMastodonにセキュリティリスクを発生させる可能性がありますし、本家Mastodonの対応を待つにしてもkmyblueのほうに来てしまったセキュリティインシデントの対応に困ります（本家がなかなか対応してくれない可能性を考えると削除しづらい）。もし間違ってkmyblueに来た場合、kmyblue開発者の責任で振り分けを行います。

## サポートするバージョン

下記以外のバージョンは、セキュリティインシデントを起票されても対応しません。

- 最新メジャーバージョン、かつ、最新マイナーバージョン
  - 最新メジャーバージョンのサポートは、次のメジャーバージョンが出た時点で終了します
- LTS
  - LTSのサポートは、次のLTSが出た時点で終了します（ただし移行期間があってもいいと思ってるので、１〜３ヶ月以内ならセキュリティインシデントの程度に応じて対応する可能性があります）
