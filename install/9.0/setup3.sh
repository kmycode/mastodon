cat << EOF

================== [kmyblue setup script 3] ======================
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

============== [kmyblue setup script 3 completed] ================

Input this command to continue setup:
  sudo su - mastodon
  ./setup4.sh

EOF
