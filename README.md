# kmyblue

[![Ruby Testing](https://github.com/kmycode/mastodon/actions/workflows/test-ruby.yml/badge.svg)](https://github.com/kmycode/mastodon/actions/workflows/test-ruby.yml)

kmyblueは[Mastodon](https://github.com/mastodon/mastodon)のフォークです。創作作家のためのMastodonを目指して開発しました。

kmyblueはフォーク名であり、同時に[サーバー名](https://kmy.blue)でもあります。以下は特に記述がない限り、フォークとしてのkmyblueをさします。

kmyblueは AGPL ライセンスで公開されているため、どなたでも自由にフォークし、このソースコードを元に自分でサーバーを立てて公開することができます。また ActivityPub に参加することもできます。確かにサーバーkmyblueは創作作家向けのものですが、フォークとしてのkmyblueはサーバーとは別物であり、作者と政治的に対立するコミュニティ、創作活動の一部（エロ関係含む）または全体を否定するコミュニティなどにも平等にお使いいただけます。サーバーkmyblueのルールを適用する必要もなく、「Anyone But Kmyblue」なルールを設定することすら許容されます。  
kmyblueは、特に未収載投稿の検索が強化されているため、ローカルタイムラインに掲載されていない投稿も検索・購読することが可能な場合があります。閉鎖的なコミュニティ、あまり目立ちたくないコミュニティには特に強力な機能を提供します。それ以外のコミュニティに対しても、kmyblueはプライバシーを考慮したうえで強力な検索・購読機能を提供するため、汎用サーバーとして利用するにも十分な機能が揃っています。

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

### 本家Mastodonへの積極的追従

kmyblueは、いくつかのフォークと異なり、追加機能を控えめにする代わりに本家Mastodonに積極的に追従を行います。バージョン 4 には 4 のよさがありますが、技術的に可能である限り、バージョン 5 へのアップグレードもやぶさかではありません。  
kmyblueの追加機能そのままに、Mastodonの新機能も利用できるよう調整を行います。

### ゆるやかな内輪での運用

kmyblueは同人向けサーバーとして出発したため、同人作家に需要のある「内輪ノリを外部にできるだけもらさない」という部分に特化しています。

「ローカル公開」という機能によって、「ローカルタイムラインに流すが他のサーバーの連合タイムラインに流さない」投稿が可能です。ただしMisskeyのローカル限定とは異なり、他のサーバーのフォロワーのタイムラインにも投稿は流れます。自分のサーバーの中で内輪で盛り上がって、他のサーバーの連合タイムラインには外面だけの投稿を流すことも可能です。

また、通常のMastodonでは公開投稿を他のサーバーの人に自由に検索できるようにすることも可能ですが、kmyblueでは未収載投稿に対して同様の設定が可能です。つまり、ローカルタイムラインにも連合タイムラインにも流れない、誰かの目に自然に触れることはない、でも特定キーワードを使った検索では引っかかりたい、そのような需要に対応できます。ただしこの検索ができるのはMisskeyならびにkmyblueフォークだけです。

### 絵文字リアクション対応

kmyblueは絵文字リアクションに対応しているフォークの１つです。絵文字リアクションは Misskey 標準搭載の機能で、需要が高い機能である割には、サーバーに負荷がかかるため本家Mastodonには搭載されていません。絵文字リアクションによってユーザーは「お気に入り」以上「返信」以下のコミュニケーションを気軽に行うことができ、Mastodonの利用体験が向上します。  
各ユーザーが自分の投稿に絵文字リアクションをつけることを拒否できるほか、サーバー全体として絵文字リアクションを無効にする設定も可能です（この場合、他サーバーから来た絵文字リアクションはお気に入りとして保存されます）

### プライバシーへの配慮

- **ローカル公開** - ローカルタイムラインにのみ投稿を流し、他サーバーの連合タイムラインに流しません。他のサーバーには未収載として配信されます
- **検索許可** - 投稿ごとに検索を許可する範囲を細かく制御できます。これは本家Mastodonにはない特徴です
- **Misskeyへの投稿配送制限** - Misskeyへ未収載投稿を配送する時、「フォロワーのみ」に変換する設定がユーザー個別に可能です。Misskeyの自由な検索からkmyblue上の投稿を保護します

## kmyblueのブランチ

- **main** - 管理者が本家MastodonにPRするときに使うことがあります
- **kb_development** - 現在kmyblue本体で使われているソースコードです
- **kb_lts** - LTSの管理に使います。LTSはこのブランチから公開されます
- **kb_patch** - 修正パッチの管理に使います。マイナーバージョンアップデートは通常このブランチから公開されます
- **kb_migration** - 本家Mastodonへの追従を目的としたブランチです。`kb_development`上で開発を進めているときに利用します
- **kb_migration_development** - 本家Mastodonへ追従し、かつその上で開発するときに使うブランチです。最新の本家コードでリファクタリングが行われ、`kb_development`と`kb_migration`の互換性の維持が困難になったときに利用します。ここで追加された機能は原則、本家Mastodonのバージョンアップと同時に`kb_development`に反映されます

## 本家Mastodonからの追加機能

kmyblueは、本家Mastodonにいくつかの改造を加えています。以下に示します。ただし以下はあくまで一例です。ほぼ完全な一覧は、以下の記事を参照してください。

https://note.com/kmycode/n/n5fd5e823ed40

### ローカル公開

未収載を拡張した公開範囲です。本来のみ収載の公開範囲に加えて、自分のサーバーのローカルタイムラインに掲載されます。他のサーバーの連合タイムラインに載せたくない、自分と属性の近い人達が集まったサーバーと自分のフォロワーにだけ見せたい投稿に用います。

### スタンプ（絵文字リアクション）

kmyblue内での呼称はスタンプですが、一般には絵文字リアクションと呼ばれる機能です。自分や他人の投稿に絵文字をつけることができます。kmyblueのスタンプは Fedibird の絵文字リアクションと互換性のある API を持っているため、Fedibird 対応アプリでkmyblueのスタンプ機能を利用できる場合があります。

kmyblueは、１つのアカウントが１つの投稿に複数のスタンプ（絵文字リアクション）を最大３個までつけることが可能です。また、下記機能にも対応しています。

- 他のサーバーのアカウントがつけたスタンプに相乗りする
- 自分がスタンプを付けた投稿一覧を見る
- トレンド投稿の選定条件にスタンプを付けたアカウントの数を考慮する
- 投稿の自動削除で削除条件にスタンプの数を指定する

kmyblueは、他のサーバーの投稿にスタンプをつけることで、相手サーバーに情報を送信します。ただしスタンプに対応していないサーバーにおいては、お気に入りとして通知されます。

### アンテナ

「自分はフォローしていないが連合タイムラインに流れているアカウント」の投稿を購読することが可能です。アンテナはドメイン、アカウント、ハッシュタグ、キーワードの４種類の絞り込み条件を持ち、複合指定することで AND 条件として働きます。アンテナによって検出された投稿は、指定されたリスト、またはホームタイムラインに追加されます。  
アンテナ専用のタイムラインも存在し、ここではアンテナで拾った投稿が流れます。これはリストやホームに配置しなくても容易に確認できます。

ドメイン購読において、自分自身のドメインを指定できることも特長の１つです。また、STL（ソーシャルタイムライン）モードにも対応しています。

絞り込まれた投稿は、さらにドメイン、アカウント、ハッシュタグ、キーワードの４種類の条件を指定して除外することができます。これはOR条件として働きます。

アンテナの条件指定は複雑ですが、Webクライアントに搭載された編集画面では、事前の説明がなくても条件指定の落とし穴に気づきやすいようにしています。

自分の投稿がアンテナに検出されるのを拒否することもできます。この拒否設定は、ActivityPubで他サーバーにも共有されますが、対応するかはそれぞれの判断に委ねられます。

### サークル

自分のフォロワーの中でも特に対象を絞ってサークルという単位にまとめ、対象アカウントのみが閲覧可能な投稿を送信できます。ただしこれはMastodonサーバーとしか共有できません。（4.2.0-rc1現在、本家Mastodonではバグのため正常に受信できません）

相互フォロー限定投稿にも対応しています。

### 期間限定投稿

例えば`#exp10m`タグをつけると、その投稿は 10 分後に自動削除されます。秒、分、時、日の４種類の指定に対応、数値は４桁まで、5 分未満の時間指定も可能ですが編集が絡むと意図通り動作しないことがあります。

このハッシュタグがついた投稿を編集しても、実際に削除される時刻は編集時刻ではなく、投稿時刻から起算されます。

### グループ

kmyblueはグループ機能に対応しています。グループのフォロワーからグループアカウントへのメンションはすべてブーストされ、グループのフォロワー全員に届きます。なおこれは本家Mastodonでも今後実装予定の機能です。

### ドメインブロックの拡張

ドメインブロック機能が大幅に拡張され、「制限」「停止」としなくても、細分化された操作を個別にブロックすることができます。これによって、相手サーバーとの交流が完全に遮断されるリスクを減らします。適切に管理されておらず善良なユーザーとスパム／攻撃者が同居するようなサーバーへの対策として有効です。

- お気に入り・絵文字リアクションのみをブロック
- メンションのみをブロック
- 相手からのフォローを強制的に審査制にする
- 相手からのフォローを全てブロック

他にも、「自分のサーバーの特定投稿を相手サーバーに送信しない」設定が可能です。これはセンシティブな投稿などを政治的な理由で送信することが難しいサーバーへの対策として実装しました。

#### Misskey 対策

Misskey およびそのフォーク（Calckey など）は、**フォローしていないアカウントの未収載投稿**を自由に検索・購読することができます。これはMastodonの設計とは根本的に異なる仕様です。kmyblueでは、そのサーバーに未収載投稿を送信するときに「フォロワーのみ」に変更します。他のサーバーには未収載として送信されます。この動作は新規登録したばかりのユーザーにおいてはデフォルトではオフとなっており、ユーザー各自の設定が必要になります。

### モデレーションの拡張

管理の効率化、規約違反・法律違反コンテンツへの迅速な対応（特にアカウント停止を伴わずに済むようにすること）を目的として、モデレーション機能を拡張しています。

#### 各投稿の操作

各投稿について、強制的な CW 付与、強制的な画像 NSFW フラグ付与、編集履歴の削除、画像の削除、投稿の削除が行なえます。操作は即時反映されます。

#### アカウントの正規表現検索

アカウント名、表示名について正規表現で検索できます。ただし動作は重くなります。

#### 全画像の閲覧

「未収載」「フォロワーのみ」「指定された相手のみ」公開範囲のものも含め、すべての画像を閲覧できる画面があります。法令、サーバー規約に違反した画像を見つけるために必要です。

### AI 学習禁止メタタグ

ユーザー生成コンテンツが含まれる全てのページに、AI 学習を禁止するメタタグを挿入しています。ただし各ユーザーのプロフィールページ・投稿ページに限り、ユーザーは各自設定で AI 学習禁止メタタグを除去することが可能です。

### リンクのテキストと実際のリンク先の異なるものの強調表示

Misskey およびそのフォーク（Calckey など）では、MFM を利用することにより、例えば「https://google.co.jp/ 」に向けたリンクを「https://www.yahoo.co.jp/ 」というテキストで掲載することが容易です。それに関する基本的な詐欺を見分けることができます。ただし実際にフィッシング詐欺への効果があるかは疑問です。

### 投票項目数の拡張

投票について、本家Mastodonでは４項目までですが、kmyblueでは８個までに拡張しています。

### 連合から送られてくる投稿の添付画像最大数の拡張

本家Mastodonでは４個までですが、kmyblueでは８個までに拡張しています。ただし Web クライアントでの表示には、各自ユーザーによる設定が必要です。kmyblueローカルから投稿できる画像の枚数に変更はありません。

### 検索許可

ユーザーは各投稿に「検索許可」パラメータを付与できます。ここで「公開」が指定された投稿は、誰でも自由に検索機能を用いて検索することができます（全文検索に限る）。検索許可に対応していないクライアントアプリから投稿した時の値は、ユーザーが設定することができます。

これは Fedibird の「検索範囲」機能に対応します。API に互換性はありませんが、ActivityPub 仕様は共通しています。

なおMisskeyからの投稿は、検索許可が自動的に「全て」になります。

### トレンドの拡張

本家マストドンでは、センシティブフラグのついた全ての投稿がトレンドに掲載されません。kmyblueはその中でも、「センシティブフラグはついているが、画像が添付されておらず CW 付きでもない」投稿をトレンドに掲載します。

本来このような投稿はトレンドに掲載すべきでありませんが、本家Mastodonの Web クライアントでは文章だけの投稿のセンシティブフラグを自由に操作できないことを理由とした独自対応となります。

### Sidekiq ヘルスチェック

Sidekiq のヘルスチェックを目的として、３０秒に１回ずつ指定された URL に HEAD リクエストを送信します。送信先 URL は、環境変数（または`.env.production`）に`SIDEKIQ_HEALTH_FETCH_URL`として指定します。
