#!/bin/bash

###########################################################################################
# NebulaKernel Build Script (C) 2015                                                      #
#  Modified By Eliminater74   Original By RenderBroken                                    #
#                                                                                         #
# Build Script W/AnyKernel V2 Support Plus        07/22/2015                              #
#                                                                                         #
# Added: Random+YYYYMMDD Format at end of zip                                             #
# Added: SignApk to sign all zips     <--- removed for now                                #
# Added: Build.log Error Only or Full Log                                                 #
# Added: Automatic change anykernel.sh device settings                                    #
# Added: Dialog Menu system for nice clean easy GUI environment                           #
# Added: Fail Safe method for When Builds End                                             #
# Added: batch Buil                                                                       #
#                                                                                         #
#                                                                                         #
#                                                                                         #
#                                                                                         #
#                                                                                         #
#                                                                                         #
#                                                                                         #
###########################################################################################

# Store menu options selected by the user
INPUT=/tmp/menu.sh.$$
 
# Storage file for displaying cal and date command output
OUTPUT=/tmp/output.sh.$$

# trap and delete temp files
trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM

# Bash Color
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

clear

# Resources
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="zImage"
DTBIMAGE="dtb"

# Kernel Details
VER=NebulaKernel
REV="Rev6.6"
DEVICES="d850;d851;d852;d855;d855_lowmem;f400;ls990;vs985"
#BDATE=$(date +"%Y%m%d")
KVER="$RANDOM"_$(date +"%Y%m%d")


# Vars
export LOCALVERSION=~`echo $VER`
export CROSS_COMPILE=${HOME}/Builds/KERNEL-SOURCE/toolchains/arm-eabi-6.0/bin/arm-eabi-
export ARCH=arm
export SUBARCH=arm
export KBUILD_BUILD_USER=Eliminater74
export KBUILD_BUILD_HOST=HP_ENVY_dv7.com
export CCACHE=ccache
export ERROR_LOG=ERRORS

# Paths
KERNEL_DIR=`pwd`
REPACK_DIR="${HOME}/Builds/KERNEL-SOURCE/G3-AnyKernel"
PATCH_DIR="${HOME}/Builds/KERNEL-SOURCE/G3-AnyKernel/patch"
MODULES_DIR="${HOME}/Builds/KERNEL-SOURCE/G3-AnyKernel/modules"
TOOLS_DIR="${HOME}/Builds/KERNEL-SOURCE/G3-AnyKernel/tools"
RAMDISK_DIR="${HOME}/Builds/KERNEL-SOURCE/G3-AnyKernel/ramdisk"
SIGNAPK="${HOME}/Builds/KERNEL-SOURCE/SignApk/signapk.jar"
SIGNAPK_KEYS="${HOME}/Builds/KERNEL-SOURCE/SignApk"
ZIP_MOVE="${HOME}/Builds/KERNEL-SOURCE/zips"
COPY_ZIP="${HOME}/public_html/NebulaKernel"
ZIMAGE_DIR="${HOME}/Builds/KERNEL-SOURCE/NebulaKernel/arch/arm/boot"

# Functions

## Clean everything that is left over ##
function clean_all {
		rm -rf $MODULES_DIR/*
		#rm -rf ~/.ccache
		cd $REPACK_DIR
		rm -rf $KERNEL
		rm -rf $DTBIMAGE
		rm -rf *.zip
		cd $KERNEL_DIR
		echo "Deleting arch/arm/boot/*.dtb's"
		rm -rf arch/arm/boot/*dtb
		echo "Deleting arch/arm/boot/zImage*"
		rm -rf arch/arm/boot/zImage*
		echo "Deleting arch/arm/boot/Image*"
		rm -rf arch/arm/boot/Image*
		echo "Deleting firmware/synaptics/g3/*.gen.*"
		rm -rf firmware/synaptics/g3/*gen*
		echo
		make clean && make mrproper
}


## Change Variant in anykernel.sh file ##
function change_variant {
		TAG=$VARIANT
		if [ "$VARIANT" == "d855_lowmem" ]; then TAG="d855"
		echo "TAG1: $TAG"
		fi
		echo "TAG: $TAG"
		cd $REPACK_DIR
		sed -i '11s/.*/device.name1='$TAG'/' anykernel.sh
		sed -i '12s/.*/device.name2=LG-'$TAG'/' anykernel.sh
		cd $KERNEL_DIR
		#cd $REPACK_DIR
        #sed -i 's/d850/$VARIANT/g; s/d851/$VARIANT/g; s/d852/$VARIANT/g; s/d855/$VARIANT/g; s/f400/$VARIANT/g; s/ls990/$VARIANT/g; s/vs985/$VARIANT/g/g' anykernel.sh
		#UP_CASE=$VARIANT | tr '[:upper:]' '[:lower:]'
		#sed -i 's/D850/$VARIANT/g; s/D851/$VARIANT/g; s/D852/$VARIANT/g; s/D855/$VARIANT/g; s/F400/$VARIANT/g; s/LS990/$VARIANT/g; s/VS985/$VARIANT/g/g' anykernel.sh
		#cd $KERNEL_DIR
}

function show_log {
rm -f build.log; echo Initialize log >> build.log
  date >> build.log
  tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
  trap 'rm -f $tempfile; stty sane; exit 1' 1 2 3 15
  dialog --title "TAIL BOXES" \
        --begin 10 10 --tailboxbg build.log 8 58 \
        --and-widget \
        --begin 3 10 --msgbox "Press OK " 5 30 \
        2>$tempfile &
  mypid=$!
  for i in 1 2 3;  do echo $i >> build.log; sleep 1; done
  echo Done. >> build.log
  wait $mypid
  rm -f $tempfile
}

## Build Log ##  
function build_log {
		rm -rf build.log
		if [ "$ERROR_LOG" == "ERRORS" ]; then
        exec 2> >(sed -r 's/'$(echo -e "\033")'\[[0-9]{1,2}(;([0-9]{1,2})?)?[mK]//g' | tee -a build.log)
		fi
		if [ "$ERROR_LOG" == "FULL" ]; then
        exec &> >(tee -a build.log)
		fi
}


## Logging options ##
function menu_log {
DIALOG=${DIALOG=dialog}
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

$DIALOG --backtitle "Logging Options" \
	--title "Menu: Logging Options" --clear \
        --radiolist "Choose your Logging Option below" 20 61 5 \
        "Errors"  "Log only compile errors" on \
        "Full"    "Full logging" off \
        "Off" "Off: No Logging at all" off  2> $tempfile
# 0 = No Log
# 1 = FULL
# 2 = Errors Only

retval=$?

choice=`cat $tempfile`
case $retval in
  0)
	if [ "$choice" == "Errors" ]; then
	echo "Log set to Errors Only"
	export ERROR_LOG=ERRORS
	fi
	if [ "$choice" == "Full" ]; then
	echo "Log Full On"
	export ERROR_LOG=FULL
	fi
	if [ "$choice" == "Off" ]; then
	echo "Log If off"
	export ERROR_LOG=OFF
	fi
	build_log;;
  1)
    echo "Cancel pressed.";;
  255)
    echo "ESC pressed.";;
esac
}


## Pipe Output to Dialog Box ##
function pipe_output() {
	exec &> >(tee -a screen.log)
	dialog --title "$title" --tailbox screen.log 25 140
}


## Batch Build ##
function build_all() {
		OIFS=$IFS
		IFS=';'
		arr2=$DEVICES
		for x in $arr2
		do
		VARIANT="$x"
		DEFCONFIG="${x}_defconfig"
		echo "Device: $VARIANT defconfig: $DEFCONFIG"
		clean_all
		build_log
		change_variant
		make_kernel
		make_dtb
		make_modules
		make_zip
done

IFS=$OIFS

echo -e "${green}"
echo "--------------------------------------------------------"
echo "Created Successfully.."
echo "Builds Completed in:"
echo "--------------------------------------------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo

# if temp files found, delete em
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT
unset ERROR_LOG
exit
}

function make_kernel {
		echo
		make $DEFCONFIG
		make $THREAD
		cp -vr $ZIMAGE_DIR/$KERNEL $REPACK_DIR
}

function make_modules {
		rm `echo $MODULES_DIR"/*"`
		find $KERNEL_DIR -name '*.ko' -exec cp -v {} $MODULES_DIR \;
}

function make_dtb {
		$REPACK_DIR/tools/dtbToolCM -2 -o $REPACK_DIR/$DTBIMAGE -s 2048 -p scripts/dtc/ arch/arm/boot/
}

function make_zip {
		cd $REPACK_DIR
		zip -r9 NebulaKernel_"$REV"_MR_"$VARIANT"_"$KVER".zip *
		#java -jar $SIGNAPK $SIGNAPK_KEYS/testkey.x509.pem $SIGNAPK_KEYS/testkey.pk8 NebulaKernel_"$REV"_MR_"$VARIANT"_"$KVER".zip NebulaKernel_"$REV"_MR_"$VARIANT"_"$KVER"-signed.zip
		#mv NebulaKernel_"$REV"_MR_"$VARIANT"_"$KVER"-signed.zip $ZIP_MOVE
		#cp NebulaKernel_"$REV"_MR_"$VARIANT"_"$KVER".zip $COPY_ZIP
		mv NebulaKernel_"$REV"_MR_"$VARIANT"_"$KVER".zip $ZIP_MOVE
		rm -rf NebulaKernel_"$REV"_MR_"$VARIANT"_"$KVER".zip
		cd $KERNEL_DIR
}


## Finished Build Displayed in a Dialog nfo box ##
function finished_build {
	DATE_END=$(date +"%s")
	DIFF=$(($DATE_END - $DATE_START))
		if [ -e $ZIMAGE_DIR/$KERNEL ]; then
	dialog --title  "Build Finished"  --backtitle  "Build Finished" \
	--infobox  "NebulaKernel_'$REV'_MR_'$VARIANT'_'$KVER'.zip \n\
	Created Successfully..\n\
    Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds." 7 65 ; read 
	else
dialog --title  "Build Not Completed"  --backtitle  "Build Had Errors" \
	--infobox  "Build Aborted Do to errors, zImage doesnt exist,\n\
	Unsuccessful Build.." 7 65 ; read
	cd $REPACK_DIR
	rm -rf NebulaKernel_"$REV"_MR_"$VARIANT"_"$KVER".zip
	cd $KERNEL_DIR
	fi
}

DATE_START=$(date +"%s")

function build_kernels {
echo -e "${green}"
echo "NebulaKerrnel Creation Script:"
echo -e "${restore}"

## Build Menu ##
cmd=(dialog --keep-tite --menu "Select options:" 22 76 16)

options=(1 "D850"
         2 "D851"
         3 "D852"
		 4 "D855"
		 5 "D855_lowmem"
		 6 "F400"
		 7 "ls990"
		 8 "vs985"
         9 "Build All")

choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

for choice in $choices
do
    case $choice in
        1)
			VARIANT="d850"
			DEFCONFIG="d850_defconfig"
			break;;
        2)  echo "LG G3 D851 Device Picked."
            VARIANT="d851"
			DEFCONFIG="d851_defconfig"
			break;;
        3)
            VARIANT="d852"
		    DEFCONFIG="d852_defconfig"
		    break;; 
        4)
		    VARIANT="d855"
		    DEFCONFIG="d855_defconfig"
		    break;;
		5)
			VARIANT="d855_lowmem"
			DEFCONFIG="d855_lowmem_defconfig"
			break;;
		6)
			VARIANT="f400"
			DEFCONFIG="f400_defconfig"
			break;;	
		7)
			VARIANT="ls990"
			DEFCONFIG="ls990_defconfig"
			break;;
		8)
			VARIANT="vs985"
			DEFCONFIG="vs985_defconfig"
			break;;
		9) build_all
			break;;
		
    esac

done

## Clean Left over Garbage Files Y/N ##
dialog --title "Clean Garbage Files" \
	--backtitle "Linux Shell Script Tutorial Example" \
	--yesno "Do you want to clean garbage files ?" 7 60
 
	# Get exit status
	# 0 means user hit [yes] button.
	# 1 means user hit [no] button.
	# 255 means user hit [Esc] key.
	response=$?
	case $response in
	0) clean_all
	   buildkernel_msg;;
	1) echo "No Change";;
	255) echo "[ESC] key pressed.";;
esac

##  Build Kernel Y/N ##
dialog --title "Build Kernel" \
	--backtitle "Linux Shell Script Tutorial Example" \
	--yesno "Are you sure you want to build Kernel ?" 7 60
 
	# Get exit status
	# 0 means user hit [yes] button.
	# 1 means user hit [no] button.
	# 255 means user hit [Esc] key.
	response=$?
	case $response in
	0) 	build_log
		change_variant
		make_kernel
		make_dtb
		make_modules
		make_zip
		finished_build;;
	1) echo "File not deleted.";;
	255) echo "[ESC] key pressed.";;
esac
}

 function main_menu() {
while true
do

### display main menu ###
dialog --clear  --help-button --backtitle "Linux Shell Script Tutorial" \
--title "[ M A I N - M E N U ]" \
--menu "You can use the UP/DOWN arrow keys, the first \n\
letter of the choice as a hot key, or the \n\
number keys 1-5 to choose an option.\n\
Choose the TASK" 15 50 4 \
	BKernel "Build Kernels" \
	Log	"Logging Options [Log: $ERROR_LOG]" \
	Clean "Clean Source" \
	Test "Section For Testing New Stuff" \
	Exit "Exit to the shell" 2>"${INPUT}"
 
	menuitem=$(<"${INPUT}")
 
 
# make decsion 
case $menuitem in
	BKernel) build_kernels;;
	Log) menu_log;;
	Clean) clean_all ;;
	Test) build_all;;
	Exit) echo "Bye"; break;;
	255) echo "Cancel"; break;;
esac
 
 done
}
main() {
    main_menu
}

echo -e "${green}"
echo "--------------------------------------------------------"
echo "NebulaKernel_'$REV'_MR_'$VARIANT'_'$KVER'-signed.zip"
echo "Created Successfully.."
echo "Build Completed in:"
echo "--------------------------------------------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo

# if temp files found, delete em
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT
unset ERROR_LOG
main "$@"
