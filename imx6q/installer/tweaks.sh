#!/bin/sh

# some usefull things (thanks to oz_paulb from mazda3revolution.com - your code is awesome! I wish, I could understand everything ...)

get_cmu_sw_version()
{
	_ver=$(/bin/grep "^JCI_SW_VER=" /jci/version.ini | /bin/sed 's/^.*_\([^_]*\)\"$/\1/')
	_patch=$(/bin/grep "^JCI_SW_VER_PATCH=" /jci/version.ini | /bin/sed 's/^.*\"\([^\"]*\)\"$/\1/')
	_flavor=$(/bin/grep "^JCI_SW_FLAVOR=" /jci/version.ini | /bin/sed 's/^.*_\([^_]*\)\"$/\1/')

	if [[ ! -z "${_flavor}" ]]; then
		echo "${_ver}${_patch}-${_flavor}"
	else
		echo "${_ver}${_patch}"
	fi
}

get_cmu_sw_version_only()
{
	_veronly=$(/bin/grep "^JCI_SW_VER=" /jci/version.ini | /bin/sed 's/^.*_\([^_]*\)\"$/\1/')
	echo "${_veronly}"
}

log_message()
{
	echo "$*" 1>2
	echo -e "$*" >> "${MYDIR}/AIO_log.txt"
	/bin/fsync "${MYDIR}/AIO_log.txt"
}


show_message()
{
	sleep 4
	killall jci-dialog
	log_message "= POPUP: $* "
	/jci/tools/jci-dialog --info --title="MESSAGE" --text="$*" --no-cancel &
}


show_message_OK()
{
	sleep 4
	killall jci-dialog
	log_message "= POPUP: $* "
	/jci/tools/jci-dialog --confirm --title="CONTINUE INSTALLATION?" --text="$*" --ok-label="YES - GO ON" --cancel-label="NO - ABORT"
	if [ $? != 1 ]
		then
			killall jci-dialog
			break
		else
			show_message "INSTALLATION ABORTED! PLEASE UNPLUG USB DRIVE"
			sleep 5
			exit
		fi
}

add_app_json()
# script by vic_bam85
{	
	# check if entry in additionalApps.json still exists, if so nothing is to do
	count=$(grep -c '{ "name": "'"${1}"'"' /jci/opera/opera_dir/userjs/additionalApps.json)
	if [ "$count" = "0" ]
		then
			log_message "=== No entry of ${2} found in additionalApps.json, seems to be the first installation ==="
			mv /jci/opera/opera_dir/userjs/additionalApps.json /jci/opera/opera_dir/userjs/additionalApps.json.old
			# delete last line with "]" from additionalApps.json
			echo "$(cat /jci/opera/opera_dir/userjs/additionalApps.json.old)" | grep -v "]" > /jci/opera/opera_dir/userjs/additionalApps.json		
			# check, if other entrys exists
			count=$(grep -c '}' /jci/opera/opera_dir/userjs/additionalApps.json)
			if [ "$count" != "0" ]
				then
					# if so, add "," to the end of last line to additionalApps.json
					echo "$(cat /jci/opera/opera_dir/userjs/additionalApps.json)", > /jci/opera/opera_dir/userjs/additionalApps.json
					log_message "=== Found existing entrys in additionalApps.json ==="
			fi
			# add app entry and "]" again to last line of additionalApps.json
			log_message "=== Add ${2} to last line of additionalApps.json ==="
			echo '{ "name": "'"${1}"'", "label": "'"${2}"'" }' >> /jci/opera/opera_dir/userjs/additionalApps.json
			echo "]" >> /jci/opera/opera_dir/userjs/additionalApps.json
		else
			log_message "=== ${2} still exists in additionalApps.json, no modification necessary ==="
	fi
}

# disable watchdog and allow write access
echo 1 > /sys/class/gpio/Watchdog\ Disable/value
mount -o rw,remount /


MYDIR=$(dirname $(readlink -f $0))
CMU_SW_VER=$(get_cmu_sw_version)
CMU_VER_ONLY=$(get_cmu_sw_version_only)
rm -f "${MYDIR}/AIO_log.txt"


log_message "=== START LOGGING ... ==="
log_message "=== CMU_SW_VER = ${CMU_SW_VER} ==="
log_message "=== MYDIR = ${MYDIR} ==="
log_message "=== Watchdog temporary disabeld and write access enabled ==="


# first test, if copy from MZD to sd card is working to test correct mount point
cp /jci/sm/sm.conf ${MYDIR}
if [ -e ${MYDIR}/sm.conf ]
	then
		log_message "=== Copytest to sd card successful, mount point is OK ==="
		rm -f ${MYDIR}/sm.conf
	else
		log_message "=== Copytest to sd card not successful, mount point not found! ==="
		/jci/tools/jci-dialog --title="ERROR!" --text="Mount point not found, have to reboot again" --ok-label='OK' --no-cancel &
		sleep 5
		reboot
		exit
fi


show_message_OK "Version = ${CMU_SW_VER} : To continue installation press OK"


# a window will appear for 4 seconds to show the beginning of installation
show_message "START OF TWEAK INSTALLATION ..."


# disable watchdogs in /jci/sm/sm.conf to avoid boot loops if somthing goes wrong
if [ ! -e /jci/sm/sm.conf.org ]
	then
		cp -a /jci/sm/sm.conf /jci/sm/sm.conf.org
		log_message "=== Backup of /jci/sm/sm.conf to sm.conf.org ==="
	else log_message "=== Backup of /jci/sm.conf.org already there! ==="
fi
sed -i 's/watchdog_enable="true"/watchdog_enable="false"/g' /jci/sm/sm.conf
sed -i 's|args="-u /jci/gui/index.html"|args="-u /jci/gui/index.html --noWatchdogs"|g' /jci/sm/sm.conf
log_message "=== WATCHDOG IN SM.CONF PERMANENTLY DISABLED ==="


# -- Enable userjs and allow file XMLHttpRequest in /jci/opera/opera_home/opera.ini - backup first - then edit
if [ ! -e /jci/opera/opera_home/opera.ini.org ]
	then
		cp -a /jci/opera/opera_home/opera.ini /jci/opera/opera_home/opera.ini.org
		log_message "=== Backup of /jci/opera/opera_home/opera.ini to opera.ini.org ==="
	else log_message "=== Backup of /jci/opera/opera_home/opera.ini.org already there! ==="
fi
sed -i 's/User JavaScript=0/User JavaScript=1/g' /jci/opera/opera_home/opera.ini
count=$(grep -c "Allow File XMLHttpRequest=" /jci/opera/opera_home/opera.ini)
if [ "$count" = "0" ]
	then
		sed -i '/User JavaScript=.*/a Allow File XMLHttpRequest=1' /jci/opera/opera_home/opera.ini
	else
		sed -i 's/Allow File XMLHttpRequest=.*/Allow File XMLHttpRequest=1/g' /jci/opera/opera_home/opera.ini
fi
log_message "=== ENABLED USERJS AND ALLOWED FILE XMLHTTPREQUEST IN /JCI/OPERA/OPERA_HOME/OPERA.INI  ==="

# Remove fps.js if still exists
if [ -e /jci/opera/opera_dir/userjs/fps.js ]
	then mv /jci/opera/opera_dir/userjs/fps.js /jci/opera/opera_dir/userjs/fps.js.org
	log_message "=== Moved /jci/opera/opera_dir/userjs/fps.js to fps.js.org  ==="
fi

# Install Dump1090 App
show_message "INSTALL DUMP1090 APP ..."
log_message "=== BEGIN INSTALLATION OF DUMP1090 APP ==="
cp -a ${MYDIR}/config/dump1090/data_persist/dev/bin/* /tmp/mnt/data_persist/dev/bin/
cp -a ${MYDIR}/config/dump1090/data_persist/dev/dump1090 /tmp/mnt/data_persist/dev/
cp -a ${MYDIR}/config/dump1090/jci/gui/apps/_dump1090 /jci/gui/apps
cp -a ${MYDIR}/config/dump1090/usr/lib/librtlsdr.so /usr/lib/librtlsdr.so
chmod 755 /usr/lib/librtlsdr.so
log_message "=== Copied DUMP1090 App files ==="
chmod 755 /tmp/mnt/data_persist/dev/bin/rtl_adsb
chmod 755 /tmp/mnt/data_persist/dev/bin/rtl_eeprom
chmod 755 /tmp/mnt/data_persist/dev/bin/rtl_fm
chmod 755 /tmp/mnt/data_persist/dev/bin/rtl_power
chmod 755 /tmp/mnt/data_persist/dev/bin/rtl_sdr
chmod 755 /tmp/mnt/data_persist/dev/bin/rtl_tcp
chmod 755 /tmp/mnt/data_persist/dev/bin/rtl_test

cp /jci/scripts/stage_wifi.sh ${MYDIR}/stage_wifi_dump1090-before.sh
cp /jci/opera/opera_dir/userjs/additionalApps.json ${MYDIR}/additionalApps_dump1090-before.json

# delete empty lines
sed -i '/^$/ d' /jci/scripts/stage_wifi.sh
sed -i '/#!/ a' /jci/scripts/stage_wifi.sh

#add dump1090.js to stage_wifi
if [ -e /jci/scripts/stage_wifi.sh ]
	then
		if grep -Fq "# Dump1090 start" /jci/scripts/stage_wifi.sh
			then
				echo "exist"
				log_message "=== Modifications already done to /jci/scripts/stage_wifi.sh ==="
			else
				#first backup
				cp -a /jci/scripts/stage_wifi.sh /jci/scripts/stage_wifi.sh.org.dump1090
				log_message "=== Backup of /jci/scripts/stage_wifi.sh to stage_wifi.sh.org.dump1090 ==="
				echo -e "### Dump1090 start" >> /jci/scripts/stage_wifi.sh
				echo -e "dump1090 --net --interactive &" >> /jci/scripts/stage_wifi.sh
				sed -i '/Dump1090 start/ i\' /jci/scripts/stage_wifi.sh
				log_message "=== Modifications added to /jci/scripts/stage_wifi.sh ==="
			break
		fi
fi

# add dump1090 entry to /jci/opera/opera_dir/userjs/additionalApps.json
# copy additionalApps.js, if not already present
if [ ! -e /jci/opera/opera_dir/userjs/additionalApps.js ]
then
	log_message "=== No additionalApps.js available, will copy one ==="
	cp -a ${MYDIR}/config/dump1090/jci/opera/opera_dir/userjs/additionalApps.* /jci/opera/opera_dir/userjs/
	find /jci/opera/opera_dir/userjs/ -type f -name '*.js' -exec chmod 755 {} \;
fi

# create new additionalApps.json file from scratch if not already present
if [ ! -e /jci/opera/opera_dir/userjs/additionalApps.json ]
then
	log_message "=== No additionalApps.json available, generating one ==="
	echo "[" > /jci/opera/opera_dir/userjs/additionalApps.json
	echo "]" >> /jci/opera/opera_dir/userjs/additionalApps.json
	cp /jci/opera/opera_dir/userjs/additionalApps.json ${MYDIR}/additionalApps_generated.json
	chmod 755 /jci/opera/opera_dir/userjs/additionalApps.json
fi

# call function add_app_json to modify additionalApps.json
add_app_json "_dump1090" "dump1090"
cp /jci/scripts/stage_wifi.sh ${MYDIR}/stage_wifi_dump1090-after.sh
cp /jci/opera/opera_dir/userjs/additionalApps.json ${MYDIR}/additionalApps_dump1090-after.json

log_message "=== END INSTALLATION OF ANDROID AUTO HEADUNIT APP ==="


log_message "=== END OF TWEAKS INSTALLATION ==="

# a window will appear for asking to reboot automatically
sleep 2
killall jci-dialog
sleep 2
/jci/tools/jci-dialog --confirm --title="SELECTED ALL-IN-ONE TWEAKS APPLIED" --text="Click OK to reboot the system"
		if [ $? != 1 ]
		then
			sleep 8
			reboot
			exit
		fi
sleep 2
killall jci-dialog
