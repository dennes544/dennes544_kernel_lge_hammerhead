#!/bin/sh

#Change if changing tree
branch="$(git rev-parse --abbrev-ref HEAD)"
remote=origin

#Developer mode
devmode=y

git remote update "$remote"
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "$remote"/"$branch")
BASE=$(git merge-base HEAD "$remote"/"$branch")

#Change if changing kernel or device
if [ "$branch" = wip ]; then
	kernel="dennes544"
elif [ "$branch" = f2fs_wip ]; then
	kernel="dennes544_f2fs"
elif [ "$branch" = ext4_wip ]; then
	kernel="dennes544_ext4"
fi
config="hammerhead_defconfig"
cmdline="console=ttyHSL0,115200,n8 androidboot.hardware=hammerhead user_debug=31 msm_watchdog_v2.enable=1"
ps=2048
base=0x00000000
ramdisk_offset=0x02900000
tags_offset=0x02700000

export ARCH=arm
export SUBARCH=arm
export CROSS_COMPILE=arm-eabi-
export PATH=~/toolchain/bin:~/bin:$PATH
ramdisk=ramdisk
kerneltype="zImage-dtb"
jobcount="-j$(grep -c ^processor /proc/cpuinfo)"
build=~/www/37.143.9.176/"$kernel"/
dat=`date +%d-%m-%y`
zipname="$kernel"_$dat.zip

cleanme() {
	if [ -f arch/arm/boot/"$kerneltype" ]; then
		rm -rf ozip/boot.img
		rm -rf arch/arm/boot/"$kerneltype"
		make clean && make mrproper
	fi
}

rm -rf out
mkdir out
mkdir out/tmp

build() {
	make "$config"
	make "$jobcount"
}

bootpack() {
	if [ -f arch/arm/boot/"$kerneltype" ]; then
		cp arch/arm/boot/"$kerneltype" out
		mkbootfs ramdisk | gzip > out/ramdisk.gz
		mkbootimg --kernel out/"$kerneltype" --ramdisk out/ramdisk.gz --cmdline "$cmdline" --base $base --pagesize $ps --ramdisk_offset $ramdisk_offset --tags_offset $tags_offset --output ozip/boot.img
	fi
}

zippack() {
	if [ -f ozip/boot.img ]; then
		cd ozip
		if [ -f "$build"/dennes544/"$zipname" ]; then
			rm -rf "$build"/dennes544/"$zipname"
		fi
		zip -r ../"$zipname" ./
		mv ../"$zipname" "$build"/dennes544
		rm -rf out
		cd ..
	fi
}

if [ $LOCAL = $REMOTE ]; then
    echo "Up to date"
elif [ $LOCAL = $BASE ]; then
    echo "Need to pull"
    changed=y
fi

if [ "$devmode" = y ]; then
    echo "Developer mode!"
    build
    bootpack
    read -p "Pack zip now? (y/n)" answ
    case "$answ" in
	y|Y)
	    zippack
    esac
elif [ "$changed" = y ]; then
    git pull origin "$tree"
    cleanme
    build
    bootpack
    zippack
fi
