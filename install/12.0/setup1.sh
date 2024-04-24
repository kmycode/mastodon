VERSION=12.0

cat << EOF

Hello, new kmyblue admin.

================== [kmyblue setup script 1] ======================
INPUT kmyblue version for install

  - lts   : [RECOMMENDED] The long time support version
  - latest: The latest version

  - debug : [deprecated] The version in development
  - abort : Abort the setup script

EOF

KMYBLUE_VERSION=unset
until [ "$KMYBLUE_VERSION" == "lts" ] || [ "$KMYBLUE_VERSION" == "latest" ] || [ "$KMYBLUE_VERSION" == "debug" ] || [ "$KMYBLUE_VERSION" == "abort" ]
do
  echo -n "kmyblue version for install [lts/latest/debug/abort]: "
  read KMYBLUE_VERSION
done

if [ "$KMYBLUE_VERSION" == "abort" ]; then
  echo Good bye.
  exit
fi

cat << EOF

================== [kmyblue setup script 1] ======================
apt updates and upgrades

EOF

apt update && apt upgrade -y

cat << EOF

================== [kmyblue setup script 1] ======================
Install basis softwares

EOF

apt install -y curl wget gnupg apt-transport-https lsb-release ca-certificates

cat << EOF

================== [kmyblue setup script 1] ======================
Install Node.js

EOF

# Node.js
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update && sudo apt-get install nodejs -y

cat << EOF

================== [kmyblue setup script 1] ======================
Install PostgreSQL

EOF

# PostgreSQL
wget -O /usr/share/keyrings/postgresql.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list

cat << EOF

================== [kmyblue setup script 1] ======================
Install packages

EOF

# 必要なパッケージをまとめてインストール
apt update
apt install -y \
  imagemagick ffmpeg libpq-dev libxml2-dev libxslt1-dev file git-core \
  g++ libprotobuf-dev protobuf-compiler pkg-config nodejs gcc autoconf \
  bison build-essential libssl-dev libyaml-dev libreadline6-dev \
  zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev \
  nginx redis-server redis-tools postgresql postgresql-contrib \
  certbot python3-certbot-nginx libidn11-dev libicu-dev libjemalloc-dev

cat << EOF

================== [kmyblue setup script 1] ======================
Initialize yarn

EOF

corepack enable
yarn set version classic

cat << EOF

================== [kmyblue setup script 1] ======================
Install requested package

EOF

# Mastodonパッケージにもnode-gypは入ってるけど、npmのほうからグローバルにインストールしないと
# yarn installで一部のOptionalパッケージインストール時にエラーが出てしまう様子
npm i -g node-gyp

cat << EOF

================== [kmyblue setup script 1] ======================
Add mastodon user

Input user information (No need to type)

EOF

# mastodonユーザーを追加
adduser --disabled-login mastodon

cat << EOF

================== [kmyblue setup script 1] ======================
Create PostgreSQL mastodon user

EOF

# PostgreSQLにmastodonユーザーを追加
sudo -u postgres psql << EOF
  CREATE USER mastodon WITH PASSWORD 'ohagi' CREATEDB;
EOF

cat << EOF

================== [kmyblue setup script 1] ======================
Download kmyblue

EOF

# kmyblueソースコードをダウンロード
# 続きのシェルスクリプトをgit管理外にコピーし権限を与える
su - mastodon <<EOF
git clone https://github.com/kmycode/mastodon.git live
cp /home/mastodon/live/install/$VERSION/setup2.sh /home/mastodon/setup2.sh
chmod +x /home/mastodon/setup2.sh
EOF

cat << EOF

================== [kmyblue setup script 1] ======================
Checkout tag on kmyblue repository

EOF

# kmyblueのリポジトリをチェックアウト
cd /home/mastodon/live
git config --global --add safe.directory /home/mastodon/live
if [ "$KMYBLUE_VERSION" == "debug" ]; then
  echo 'DEBUG'
elif [ "$KMYBLUE_VERSION" == "newest" ] || [ "$KMYBLUE_VERSION" == "latest" ]; then
  sudo -u mastodon git checkout $(git tag -l | grep -E '^kb[0-9]' | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)
else
  # LTS
  sudo -u mastodon git checkout $(git tag -l | grep -E '^kb[0-9].*lts$' | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)
fi
git config --global --unset safe.directory /home/mastodon/live

cat << EOF

================== [kmyblue setup script 1] ======================
Install rbenv to control Ruby versions

EOF

# Rubyバージョン管理用のrbenvをインストール、初期設定
su - mastodon <<EOF
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
cd ~/.rbenv && src/configure && make -C src
echo 'export PATH="\$HOME/.rbenv/bin:\$PATH"' >> ~/.bashrc
echo 'eval "\$(rbenv init -)"' >> ~/.bashrc
EOF

cat << EOF

================== [kmyblue setup script 1] ======================
Copy setting files and services

EOF

# これを設定しておかないと、Web表示時にNginxがPermission Errorを起こす
chmod o+x /home/mastodon

# 必要なファイルをコピー
cp /home/mastodon/live/dist/nginx.conf /etc/nginx/sites-available/mastodon
ln -s /etc/nginx/sites-available/mastodon /etc/nginx/sites-enabled/mastodon
cp /home/mastodon/live/dist/mastodon-*.service /etc/systemd/system/
systemctl daemon-reload

# ---------------------------------------------------

cat << EOF

============== [kmyblue setup script 1 completed] ================

Input this command to continue setup:
  sudo su - mastodon
  ./setup2.sh

EOF
