
cat << EOF

================ [imagemagick 7 setup script] ====================
Remove old ImageMagick

EOF

apt remove -y imagemagick
apt autoremove -y

cat << EOF

================ [imagemagick 7 setup script] ====================
Download source

EOF

git clone https://github.com/ImageMagick/ImageMagick.git ImageMagick
cd ImageMagick
git checkout $(git tag -l | grep -E '^7' | sort -V | tail -n 1)

cat << EOF

================ [imagemagick 7 setup script] ====================
Install dependent packages

EOF

apt update
apt install -y \
    libjpeg-dev libpng-dev libpng16-16 libltdl-dev libheif-dev libraw-dev libtiff-dev libopenjp2-tools \
    libopenjp2-7-dev libjpeg-turbo-progs libfreetype6-dev libheif-dev libfreetype6-dev libopenexr-dev \
    libwebp-dev libgif-dev

cat << EOF

================ [imagemagick 7 setup script] ====================
Configure

EOF

./configure --with-modules --enable-file-type --with-quantum-depth=32 --with-jpeg=yes --with-png=yes \
    --with-gif=yes --with-webp=yes --with-heic=yes --with-raw=yes --with-tiff=yes --with-openjp2 \
    --with-freetype=yes --with-webp=yes --with-openexr=yes --with-gslib=yes --with-gif=yes --with-perl=yes \
    --with-jxl=yes

cat << EOF

================ [imagemagick 7 setup script] ====================
Make

EOF

make

cat << EOF

================ [imagemagick 7 setup script] ====================
Make install

EOF

make install
ldconfig /usr/local/lib

cat << EOF

=========== [imagemagick 7 setup script completed] ===============
ImageMagick 7 setup is completed!
Please check AVIF format on your Mastodon.

To check ImageMagick version:
  exec bash
  convert -version

Or
  sudo su - mastodon
  convert -version

EOF

