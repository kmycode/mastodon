VERSION=9.0

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
cp /home/mastodon/live/install/$VERSION/setup3.sh /home/mastodon/setup3.sh
cp /home/mastodon/live/install/$VERSION/setup4.sh /home/mastodon/setup4.sh
chmod +x /home/mastodon/setup2.sh
chmod +x /home/mastodon/setup3.sh
chmod +x /home/mastodon/setup4.sh
EOF

# ---------------------------------------------------

cat << EOF

============== [kmyblue setup script 1 completed] ================

Input this command to continue setup:
  sudo su - mastodon
  ./setup2.sh

./setup2.sh parameters (kmyblue version selection):
  ./setup2.sh          -- LTS
  ./setup2.sh latest   -- Latest version
  ./setup2.sh debug    -- [Deprecated] Newest commit

EOF
