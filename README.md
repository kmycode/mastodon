# ![kmyblue icon](https://raw.githubusercontent.com/kmycode/mastodon/kb_development/app/javascript/icons/favicon-48x48.png) kmyblue

[![Ruby Testing](https://github.com/kmycode/mastodon/actions/workflows/test-ruby.yml/badge.svg)](https://github.com/kmycode/mastodon/actions/workflows/test-ruby.yml)

kmyblueは[Mastodon](https://github.com/mastodon/mastodon)のフォークです。創作作家のためのMastodonを目指して開発しました。

kmyblueはフォーク名であり、同時に[サーバー名](https://kmy.blue)でもあります。以下は特に記述がない限り、フォークとしてのkmyblueをさします。

kmyblueは AGPL ライセンスで公開されているため、どなたでも自由にフォークし、このソースコードを元に自分でサーバーを立てて公開することができます。確かにサーバーkmyblueは創作作家向けのものですが、フォークとしてのkmyblueはAGPLでライセンスつけられており、ルールは全くの別物です。創作活動の一部（エロ関係含む）または全体を否定するコミュニティなどにも平等にお使いいただけます。サーバーkmyblueのルールを適用する必要もなく、「Anyone But Kmyblue」なルールを設定することすら許容されます。  
kmyblueは、特に非収載投稿の検索が強化されているため、ローカルタイムラインに掲載されていない投稿も検索・購読することが可能な場合があります。閉鎖的なコミュニティ、あまり目立ちたくないコミュニティには特に強力な機能を提供します。それ以外のコミュニティに対しても、kmyblueはプライバシーを考慮したうえで強力な検索・購読機能を提供するため、汎用サーバーとして利用するにもある程度十分な機能が揃っています。

ただしkmyblueにおいて**テストコードは飾り**でしかありません。これはkmyblueを利用する人が本家Mastodonより圧倒的に少なく、バグやセキュリティインシデントを発見するだけの人数が足りないことを意味します。kmyblueは対策として自動テストを拡充しています。独自機能のテストを記述するだけでなく、本家のテストコードの補強も行っておりますが、確認漏れは必ず発生するものです。不具合が発生しても自己責任になります。既知のバグもいくつかありますし、直す予定のないものも含まれます。

テストコード、Lint どちらも動いています。

## インストール方法

[Wiki](https://github.com/kmycode/mastodon/wiki/Installation)を参照してください。

## 開発への参加方法

CONTRIBUTING.mdを参照してください。

## テスト

```
# デバッグ実行（以下のいずれか）
foreman start
DB_USER=postgres DB_PASS=password foreman start

# 一部を除く全てのテストを行う
RAILS_ENV=test bundle exec rspec spec

# ElasticSearch連携テストを行う
新
RAILS_ENV=test ES_ENABLED=true bundle exec rspec --tag search
旧
RAILS_ENV=test ES_ENABLED=true RUN_SEARCH_SPECS=true bundle exec rspec spec/search
```

## kmyblueの強み

追加の詳細は下記記事もご覧ください。

https://note.com/kmycode/n/n5fd5e823ed40

以下に書いているもの以外にも多数の機能が存在します。

### 本家Mastodonへの積極的追従

kmyblueは、いくつかのフォークと異なり、追加機能を控えめにする代わりに本家Mastodonに積極的に追従を行います。kmyblueの追加機能そのままに、Mastodonの新機能も利用できるよう調整を行います。

### ゆるやかな内輪での運用

kmyblueは同人向けサーバーとして出発したため、同人作家に需要のある「内輪ノリを外部にできるだけもらさない」という部分に特化しています。

「ローカル公開」という機能によって、「ローカルタイムラインに流すが他のサーバーの連合タイムラインに流さない」投稿が可能です。ただしMisskeyのローカル限定とは異なり、他のサーバーのフォロワーのタイムラインにも投稿は流れます。自分のサーバーの中で内輪で盛り上がって、他のサーバーの連合タイムラインには外面だけの投稿を流すことも可能です。

「サークル」という機能によって、特定のフォロワーにだけ見える投稿を行うことも可能です。その投稿に返信することで、相手サークルの会話に参加することも可能です。ただしサークル投稿を正常に処理できるソフトウェアは現在、kmyblue・Fedibirdに限ります。

また、通常のMastodonでは公開投稿を他のサーバーの人に自由に検索できるようにすることも可能ですが、kmyblueでは非収載投稿に対して同様の設定が可能です。つまり、ローカルタイムラインにも連合タイムラインにも流れない、誰かの目に自然に触れることはない、でも特定キーワードを使った検索では引っかかりたい、そのような需要に対応できます。ただしこの検索ができるのはMisskeyならびにkmyblueフォークだけです。

内輪とは自分のサーバーに限ったものではありません。内輪同士で複数のサーバーを運営するとき、お互いが深く繋がれるフレンドサーバーというシステムも用意しています。

### 少人数サーバーでの運用

kmyblueは、人の少ないサーバーでの運用を考慮して設計しています。そのため、他のサーバーのアカウントの購読機能はFedibirdほど発達していませんし、人の多いサーバー向けの独自改造もほとんど存在しません。

ただしサーバーの負荷については一部度外視している部分があります。たとえばスタンプ機能はサーバーへ著しい負荷をかける場合があります。ただしスタンプ機能そのものを無効にする管理者オプションも存在します。

### 比較的高い防御力

kmyblueでは、「Fediverseは将来的に荒むのではないか」「Fediverseは将来的にスパムに溢れるのではないか」を念頭に設計している部分があります。

個別ユーザー向けの設定項目が複数あります。Misskeyは、たとえMastodonの投稿であっても非収載投稿を自由に検索できますが、kmyblueではそれをブロックできるユーザー設定が存在します。また、他の人からのスタンプの受け入れを制限する設定も可能であり、例えば他のサーバーから好ましくないスタンプを受け取ることを防止できます。

管理者向けには、スパムへの利用を前提とした正規表現可能なNGワード設定、細かい指定が可能な拡張ドメインブロック機能を用意しています。

ただし防御力の高さは自由を犠牲にします。例えばkmyblueは、絵文字リアクションの表示サイズ調整機能など、MisskeyやFedibirdには当たり前のようにある表示設定は存在しません。騒がしくなるようなものはあまり作りたいとは考えていません。

### その他の主な機能

- スタンプ（絵文字リアクション）による手軽な交流
- 検索機能の強化（検索許可）
- 充実したテストコード

## kmyblueのブランチ

- **main** - 管理者が本家MastodonにPRするときに使うことがあります
- **kb_development** - 現在kmyblue本体で使われているソースコードです
- **kb_lts** - LTSの管理に使います。LTSはこのブランチから公開されます
- **kb_patch** - 修正パッチの管理に使います。マイナーバージョンアップデートは通常このブランチから公開されます
