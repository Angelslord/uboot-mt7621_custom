#!/bin/bash

# Toolchain path
Toolchain=$(cd ../openwrt*/toolchain-mipsel*/bin; pwd)'/mipsel-openwrt-linux-'
Staging=${Toolchain%/toolchain-*}

echo "CROSS_COMPILE=${Toolchain}"
echo "STAGING_DIR=${Toolchain%/toolchain-*}"
cd $(dirname "$0")

# 🔹 Hardcoded Configuration Values
FLASH_TYPE="NAND"
MTDPARTS="512k(u-boot),512k(u-boot-env),256k(factory),-(firmware)"
KERNEL_OFFSET="0x140000"
RESET_PIN=8
SYSLED_GPIO=0
CPU_FREQ=880
RAM_FREQ=1200
DDR_PARAM="DDR3-256MiB"
BAUDRATE=115200

echo "Using Static Configuration:"
echo "FLASH_TYPE=${FLASH_TYPE}"
echo "MTDPARTS=${MTDPARTS}"
echo "KERNEL_OFFSET=${KERNEL_OFFSET}"
echo "RESET_PIN=${RESET_PIN}"
echo "SYSLED_GPIO=${SYSLED_GPIO}"
echo "CPU_FREQ=${CPU_FREQ} MHz"
echo "RAM_FREQ=${RAM_FREQ} MT/s"
echo "DDR_PARAM=${DDR_PARAM}"
echo "BAUDRATE=${BAUDRATE}"

# 🔹 Select Defconfig Based on Flash Type
DEFCONFIG="configs/mt7621_build_defconfig"
if [ "$FLASH_TYPE" = 'NOR' ]; then
	cp configs/mt7621_nor_template_defconfig ${DEFCONFIG}
	echo -e "CONFIG_MTDPARTS_DEFAULT=\"mtdparts=raspi:$MTDPARTS\"" >> ${DEFCONFIG}
elif [ "$FLASH_TYPE" = 'NAND' ]; then
	cp configs/mt7621_nand_template_defconfig ${DEFCONFIG}
	echo -e "CONFIG_MTDPARTS_DEFAULT=\"mtdparts=nand0:$MTDPARTS\"" >> ${DEFCONFIG}
else
	cp configs/mt7621_nmbm_template_defconfig ${DEFCONFIG}
	echo -e "CONFIG_MTDPARTS_DEFAULT=\"mtdparts=nmbm0:$MTDPARTS\"" >> ${DEFCONFIG}
fi

# 🔹 Set Kernel Offset
if [ "$FLASH_TYPE" = 'NOR' ]; then
	echo "CONFIG_DEFAULT_NOR_KERNEL_OFFSET=$KERNEL_OFFSET" >> ${DEFCONFIG}
else
	echo "CONFIG_DEFAULT_NAND_KERNEL_OFFSET=$KERNEL_OFFSET" >> ${DEFCONFIG}
fi

# 🔹 Set Reset Button GPIO
echo -e "#ifndef __CONFIG_MT7621_RESET_LED\n#define __CONFIG_MT7621_RESET_LED" >> ./include/configs/mt7621-common.h
echo "CONFIG_FAILSAFE_ON_BUTTON=y" >> ${DEFCONFIG}
echo "#define MT7621_BUTTON_RESET $RESET_PIN" >> ./include/configs/mt7621-common.h
echo "#define MT7621_LED_STATUS1 $SYSLED_GPIO" >> ./include/configs/mt7621-common.h
echo "#endif" >> ./include/configs/mt7621-common.h

# 🔹 Set CPU Frequency
echo "CONFIG_MT7621_CPU_FREQ_LEGACY=$CPU_FREQ" >> ${DEFCONFIG}

# 🔹 Set RAM Frequency
echo "CONFIG_MT7621_DRAM_FREQ_${RAM_FREQ}_LEGACY=y" >> ${DEFCONFIG}

# 🔹 Set DDR Parameters
case "$DDR_PARAM" in
DDR2-64MiB)
	echo "CONFIG_MT7621_DRAM_DDR2_512M_LEGACY=y" >> ${DEFCONFIG}
	;;
DDR2-128MiB)
	echo "CONFIG_MT7621_DRAM_DDR2_1024M_LEGACY=y" >> ${DEFCONFIG}
	;;
DDR2-W9751G6KB-64MiB-1066MHz)
	echo "CONFIG_MT7621_DRAM_DDR2_512M_W9751G6KB_A02_1066MHZ_LEGACY=y" >> ${DEFCONFIG}
	;;
DDR2-W971GG6KB25-128MiB-800MHz)
	echo "CONFIG_MT7621_DRAM_DDR2_1024M_W971GG6KB25_800MHZ_LEGACY=y" >> ${DEFCONFIG}
	;;
DDR2-W971GG6KB18-128MiB-1066MHz)
	echo "CONFIG_MT7621_DRAM_DDR2_1024M_W971GG6KB18_1066MHZ_LEGACY=y" >> ${DEFCONFIG}
	;;
DDR3-128MiB)
	echo "CONFIG_MT7621_DRAM_DDR3_1024M_LEGACY=y" >> ${DEFCONFIG}
	;;
DDR3-256MiB)
	echo "CONFIG_MT7621_DRAM_DDR3_2048M_LEGACY=y" >> ${DEFCONFIG}
	;;
DDR3-512MiB)
	echo "CONFIG_MT7621_DRAM_DDR3_4096M_LEGACY=y" >> ${DEFCONFIG}
	if [ -n "$(grep MT7621_DRAM_FREQ_1200_LEGACY ${DEFCONFIG})" ]; then
		echo "The max DRAM speed for 512 MiB RAM is 1066 MT/s"
		sed -i 's/MT7621_DRAM_FREQ_1200_LEGACY/MT7621_DRAM_FREQ_1066_LEGACY/' ${DEFCONFIG}
	fi
	;;
DDR3-128MiB-KGD)
	echo "CONFIG_MT7621_DRAM_DDR3_1024M_KGD_LEGACY=y" >> ${DEFCONFIG}
	;;
esac

# 🔹 Set Baud Rate
echo "CONFIG_BAUDRATE=${BAUDRATE}" >> ${DEFCONFIG}

# 🔹 Compile U-Boot
make mt7621_build_defconfig
make CROSS_COMPILE=${Toolchain} STAGING_DIR=${Staging}
make savedefconfig

# 🔹 Create Output Directory and Move Binaries
mkdir -p archive
cat defconfig > archive/mt7621_defconfig
mv u-boot-mt7621.bin archive/
mv u-boot.img archive/

echo "✅ Build Complete. Artifacts are saved in the 'archive/' folder."
