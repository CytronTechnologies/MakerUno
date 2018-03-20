#!/bin/bash
#

# Figure out how will the package be called
ver=`git describe --tags --always`

package_name=cytron-makeruno-$ver
echo "Version: $ver"
echo "Package name: $package_name"

# by default we will be using arduino core version stated in arduino-version
# else we will fall back to version 1.6.21
ARDUINO_VER=1.6.21
if [ -e "package/arduino-version.txt" ]; then
	ARDUINO_VER=`cat package/arduino-version.txt`
fi
echo $ARDUINO_VER

if [ "$TRAVIS_REPO_SLUG" = "" ]; then
TRAVIS_REPO_SLUG=$(basename `git rev-parse --show-toplevel`)
fi
echo "Repo: $TRAVIS_REPO_SLUG"

PKG_URL=https://github.com/$TRAVIS_REPO_SLUG/releases/download/$ver/$package_name.zip
DOC_URL=https://forum.cytron.io/

# Create directory for the package
outdir=package/versions/$ver/$package_name
srcdir=$PWD
rm -rf package/versions/$ver
rm -rf tmp
mkdir -p $outdir
mkdir -p tmp

# Download Arduino Core
wget -qO avr-${ARDUINO_VER}.tar.bz2 http://downloads.arduino.cc/cores/avr-${ARDUINO_VER}.tar.bz2
tar xjf avr-${ARDUINO_VER}.tar.bz2 -C tmp
rm -f avr-*
cp -R tmp/avr/* $srcdir/$outdir
rm -rf tmp

# remove some files and add our own files
rm -rf $srcdir/$outdir/cores/main.cpp
rm -rf $srcdir/$outdir/firmwares
rm -rf $srcdir/$outdir/variants
cp cores/arduino/main.cpp $srcdir/$outdir/cores/arduino/main.cpp
cp bootloaders/optiboot/optiboot_makeruno.hex $srcdir/$outdir/bootloaders/optiboot/
cp boards.txt $srcdir/$outdir/boards.txt
find $srcdir/$outdir/platform.txt -exec sed -i 's|name=Arduino AVR Boards|name=Cytron AVR Boards|g' {} \;
cp -R libraries/* $srcdir/$outdir/libraries/
pushd package/versions/$ver
echo "Making $package_name.zip"
zip -qr $package_name.zip $package_name
rm -rf $package_name

# Calculate SHA sum and size
sha=`shasum -a 256 $package_name.zip | cut -f 1 -d ' '`
size=`/bin/ls -l $package_name.zip | awk '{print $5}'`
echo Size: $size
echo SHA-256: $sha

# Download latest package_cytron_arm_index.json
old_json=package_cytron_makeruno_stable.json 

if [ -e "\$srcdir/package_cytron_makeruno_index.json" ]; then
cat $srcdir/package_cytron_makeruno_index.json > $old_json
else
cat $srcdir/package/package_cytron_makeruno_index.template.json > $old_json
fi

echo "Getting latest package_cytron_makeruno_index.json"
cat $old_json

new_json=package_cytron_makeruno_index.json

echo "Making package_cytron_makeruno_index.json"
cat $srcdir/package/package_cytron_makeruno_index.template.json | \
jq ".packages[0].platforms[0].version = \"$ver\" | \
    .packages[0].platforms[0].url = \"$PKG_URL\" |\
    .packages[0].platforms[0].archiveFileName = \"$package_name.zip\" |\
    .packages[0].platforms[0].checksum = \"SHA-256:$sha\" |\
    .packages[0].platforms[0].size = \"$size\" |\
    .packages[0].platforms[0].help.online = \"$DOC_URL\"" \
    > $new_json

set +e
if [ -e "\$srcdir/package_cytron_makeruno_index.json" ]; then
echo "Merging package_cytron_makeruno_index.json"
python ../../merge_packages.py $new_json $old_json >tmp && mv tmp $new_json && rm $old_json
else
rm $old_json
fi

# deploy key
echo -n $MAKERUNO_DEPLOY_KEY > ~/.ssh/makeruno_deploy_b64
base64 --decode --ignore-garbage ~/.ssh/makeruno_deploy_b64 > ~/.ssh/makeruno_deploy
chmod 600 ~/.ssh/makeruno_deploy
echo -e "Host $DEPLOY_HOST_NAME\n\tHostname github.com\n\tUser $DEPLOY_USER_NAME\n\tStrictHostKeyChecking no\n\tIdentityFile ~/.ssh/makeruno_deploy" >> ~/.ssh/config

#update package_cytron_makeruno_index.json
git clone $DEPLOY_USER_NAME@$DEPLOY_HOST_NAME:$TRAVIS_REPO_SLUG.git ~/tmp
cp $new_json ~/tmp/
rm $new_json

popd