cd ~/live

cat << EOF

================== [kmyblue setup script 2] ======================
Checkout tag on kmyblue repository

EOF

# kmyblueの最新タグを取り込む
if [ "$1" == "debug" ]; then
  echo 'DEBUG'
elif [ "$1" == "newest" ] || [ "$1" == "latest" ]; then
  git checkout $(git tag -l | grep -E '^kb[0-9]' | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)
else
  # LTS
  git checkout $(git tag -l | grep -E '^kb[0-9].*lts$' | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)
fi

cat << EOF

================== [kmyblue setup script 2] ======================
Install rbenv to control Ruby versions

EOF

# Rubyバージョン管理用のrbenvをインストール、初期設定
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
cd ~/.rbenv && src/configure && make -C src
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc

# ---------------------------------------------------

cat << EOF

============== [kmyblue setup script 2 completed] ================

Input this command to continue setup:
  exec bash
  exit
  sudo /home/mastodon/setup3.sh

EOF
