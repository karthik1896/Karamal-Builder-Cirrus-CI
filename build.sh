#!/bin/bash

# cd To An Absolute Path
cd /tmp/rom

# export sync start time
export TZ=$TZ

# Compile
export CCACHE_DIR=/tmp/ccache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
ccache -M 5G
ccache -o compression=true
ccache -z
#Working Directory
WORK_DIR=$(pwd)

# Telegram Chat Id
ID=$TG_CHAT_ID

# Bot Token
bottoken=$TG_TOKEN

# Functions
msg() {
	curl -X POST "https://api.telegram.org/bot$bottoken/sendMessage" -d chat_id="$ID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}
file() {
	MD5=$(md5sum "$1" | cut -d' ' -f1)
	curl --progress-bar -F document=@"$1" "https://api.telegram.org/bot$bottoken/sendDocument" \
	-F chat_id="$ID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$2 | <b>MD5 Checksum : </b><code>$MD5</code>"
}

#cloning
if [ -d $WORK_DIR/Anykernel ]
then
echo "Anykernel Directory Already Exists"
else
git clone --depth=1 https://github.com/navin136/AnyKernel3 $WORK_DIR/Anykernel
fi
if [ -d $WORK_DIR/kernel ]
then
echo "kernel dir exists"
echo "Pulling recent changes"
cd $WORK_DIR/kernel && git pull
cd ../
else
git clone --depth=1  https://github.com/karthik1896/kernel_asus_sdm660-2 -b test $WORK_DIR/kernel
fi
if [ -d $WORK_DIR/toolchains/gcc64 ] && [ -d $WORK_DIR/toolchains/gcc32 ]
then
echo "gcc dir exists"
else
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android12-release $WORK_DIR/toolchains/gcc64
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android12-release $WORK_DIR/toolchains/gcc32
fi
if [ -d $WORK_DIR/toolchains/clang ]
then
echo "clang dir exists"
else
cd $WORK_DIR/toolchains
mkdir clang
cd clang
wget https://hitarashi.sayeed205.workers.dev/0:/clang-r416183b1.tar.gz
tar -xvzf clang-r416183b1.tar.gz
fi
cd $WORK_DIR/kernel

# Info
DEVICE="Asus Zenfone Max Pro M1 (X00TD)"
DATE=$(TZ=GMT-5:30 date +%d'-'%m'-'%y'_'%I':'%M)
VERSION=$(make kernelversion)
DISTRO=$(source /etc/os-release && echo $NAME)
CORES=$(nproc --all)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT_LOG=$(git log --oneline -n 1)
COMPILER=$($WORK_DIR/toolchains/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

#Starting Compilation
msg "<b>========OK-Kernel========</b>%0A<b>Hey Karthik!! Kernel Build Triggered !!</b>%0A<b>Device: </b><code>$DEVICE</code>%0A<b>Kernel Version: </b><code>$VERSION</code>%0A<b>Date: </b><code>$DATE</code>%0A<b>Host Distro: </b><code>$DISTRO</code>%0A<b>Host Core Count: </b><code>$CORES</code>%0A<b>Compiler Used: </b><code>$COMPILER</code>%0A<b>Branch: </b><code>$BRANCH</code>%0A<b>Last Commit: </b><code>$COMMIT_LOG</code>%0A<b>Build Coming !! Stay Online Bruh</b>"
BUILD_START=$(date +"%s")
export ARCH=arm64
export SUBARCH=arm64
export PATH="$WORK_DIR/toolchains/gcc64/bin/:$WORK_DIR/toolchains/gcc32/bin/:$WORK_DIR/toolchains/clang/bin/:$PATH"
cd $WORK_DIR/kernel
make clean && make mrproper
make O=out X00T_defconfig
make -j$(nproc --all) O=out \
      CLANG_TRIPLE=aarch64-linux-gnu- \
      CROSS_COMPILE=aarch64-linux-android- \
      CROSS_COMPILE_ARM32=arm-linux-androideabi- \
      CC=clang | tee log.txt

#Zipping Into Flashable Zip
if [ -f out/arch/arm64/boot/Image.gz-dtb ]
then
cp out/arch/arm64/boot/Image.gz-dtb $WORK_DIR/Anykernel
cd $WORK_DIR/Anykernel
zip -r9 VELOCITY-$DATE.zip * -x .git README.md */placeholder
cp $WORK_DIR/Anykernel/VELOCITY-$DATE.zip $WORK_DIR/
rm $WORK_DIR/Anykernel/Image.gz-dtb
rm $WORK_DIR/Anykernel/VELOCITY-$DATE.zip
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

#Upload Kernel

file "$WORK_DIR/VELOCITY-$DATE.zip" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"

else
file "$WORK_DIR/kernel/log.txt" "Build Failed and took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
