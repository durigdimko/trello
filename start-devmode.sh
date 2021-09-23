#! /bin/sh

# FIXME: disable this to turn off script echo
set -x

# FIXME: disable this to stop script from bailing on error
# set -e

# Reset devmode reboot counter
rm -f /var/luna/preferences/dc*

#mount new etc
mount -o bind /media/cryptofs/root/etc /etc

# Start root telnet server
telnetd -l /bin/sh

# give the system time to wake up
sleep 5

mount --bind /bin/false /usr/sbin/update
pkill -9 -f /usr/sbin/update

# PoC notification
#luna-send -f -n 1 luna://com.webos.notification/createToast '{"message": "Hello! I am running as: '"$ (id) "'"}'
DEVMODE_SERVICE_DIR="/media/cryptofs/apps/usr/palm/services/com.palmdts.devmode.service"
echo '900:00:00' > ${DEVMODE_SERVICE_DIR}/devSessionTime;

# Do our best to neuter telemetry
mkdir -p /home/root/unwritable
chattr +i /home/root/unwritable
mount --bind /home/root/unwritable/ /var/spool/rdxd/
mount --bind /home/root/unwritable/ /var/spool/uploadd/pending/
mount --bind /home/root/unwritable/ /var/spool/uploadd/uploaded/


# TODO: Check upstart daemon/process tracking (do we need to change /etc/init/devmode.conf? start sshd as daemon? )

# set devmode ssh port here
SSH_PORT="9922"

# set arch:
ARCH="armv71"
grep -qs "qemux86" /etc/hostname && ARCH="i686"

# set name
DEVMODE_SSHID="com.palm.devmode.openssh"
# set directories
OPT_DEVMODE="/opt/devmode"
OPT_SSH="/opt/openssh"
DEVELOPER_HOME="/media/developer"
DEVMODE_APP_DIR="/media/cryptofs/apps/usr/palm/applications/com.palmdts.devmode"
DEVMODE_SERVICE_DIR="/media/cryptofs/apps/usr/palm/services/com.palmdts.devmode.service"
DEVMODE_SSHID_JAILED_DIR="/var/palm/jail/${DEVMODE_SSHID}"
CRYPTO_SSH="$DEVMODE_SERVICE_DIR/binaries-${ARCH}/opt/openssh"
CRYPTO_OPT="$DEVMODE_SERVICE_DIR/binaries-${ARCH}/opt"
LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${CRYPTO_SSH}/lib/openssh"

LGERP_APPINSTALLER_DIR="/media/cryptofs/apps/usr/palm/applications/com.lgerp.appinstaller"

# Remove the previous jailed env and session if the app is updated
# * 'jailer -D' is not sufficient to clean the jailed path which does not exist in the related jail conf
if [ -f ${DEVMODE_APP_DIR}/appinfo.json ]; then
 loginedVersion=$ (node -pe "var fs=require ('fs') ;try{JSON.parse (fs.readFileSync ('${DEVMODE_SERVICE_DIR}/login.json')) ['version']}catch (e) {}"  ;)
 appVersion=$ (node -pe "var fs=require ('fs') ;try{JSON.parse (fs.readFileSync ('${DEVMODE_APP_DIR}/appinfo.json')) ['version']}catch (e) {}"  ;)
 echo "logined app version: $loginedVersion,  current installed app version: $appVersion"
 if [ "$loginedVersion"! = "$appVersion" ]; then
 echo "New App has been installed hence disabling developer mode"
 rm -rf /var/luna/preferences/devmode_enabled
 echo "Removing the previous jailed environment"
 rm -rf /var/luna/preferences/dc*
 rm -rf ${DEVMODE_SERVICE_DIR}/devSessionTime
 jailer -D -i ${DEVMODE_SSHID}
 rm -rf ${DEVMODE_SSHID_JAILED_DIR}/dev
 sleep 5;
 exit 0
 fi
fi

if [ -s ${DEVMODE_SERVICE_DIR}/download/jail_app.conf ] ; then
 mv ${DEVMODE_SERVICE_DIR}/download/jail_app.conf ${DEVELOPER_HOME}
 mv ${DEVMODE_SERVICE_DIR}/download/jail_app.conf.sig ${DEVELOPER_HOME}
fi

if [ -r ${DEVMODE_SERVICE_DIR}/download/sessionToken ] ; then
 mv -f ${DEVMODE_SERVICE_DIR}/download/sessionToken /var/luna/preferences/devmode_enabled
fi


# Make sure the ssh binaries are executable (in service directory)
if [! -x "${CRYPTO_SSH}/sbin/sshd" ] ; then
 chmod ugo+x ${CRYPTO_SSH}/sbin/sshd ${CRYPTO_SSH}/bin/ssh* ${CRYPTO_SSH}/bin/scp* || true
 chmod ugo+x ${CRYPTO_SSH}/bin/sftp ${CRYPTO_SSH}/lib/openssh/* || true
 chmod ugo+x ${CRYPTO_OPT}/devmode/usr/bin/* || true
fi

# TODO: (later) Look for "re-init" flag to re-generate ssh key if requested by app (via devkey service)
# com.palm.service.devmode could have "resetKey" method to erase /var/lib/devmode/ssh/webos_rsa
# Kind of dangerous though, since new key will need to be fetched on the desktop (after reboot)...
# We could just require a hard-reset of the TV which should blow away /var/lib/devmode/ssh/...

# Initialize the developer (client) SSH key pair, if it doesn't already exist
if [! -e /var/lib/devmode/ssh/webos_rsa ] ; then
 mkdir -p /var/lib/devmode/ssh
 chmod 0700 /var/lib/devmode/ssh
 # get FIRST six (UPPER-CASE, hex) characters of 40-char nduid from nyx-cmd
 # NOTE: This MUST match passphrase as displayed in devmode app (main.js)!
 # PASSPHRASE="`/usr/bin/nyx-cmd DeviceInfo query nduid | head -c 6 | tr 'a-z' 'A-Z'`"
 # PASSPHRASE="`/usr/bin/nyx-cmd DeviceInfo query nduid | tail -n1 | head -c 6 | tr 'a-z' 'A-Z'`"
 PASSPHRASE="`tail /var/lib/secretagent/nduid -c 40 | head -c 6 | tr 'a-z' 'A-Z'`"
 ${CRYPTO_SSH}/bin/ssh-keygen -t rsa -C "developer@device" -N "${PASSPHRASE}" -f /var/lib/devmode/ssh/webos_rsa
 # copy ssh key to /var/luna/preferences so the devmode service's KeyServer can read it and serve to ares-webos-cli tools
 cp -f /var/lib/devmode/ssh/webos_rsa /var/luna/preferences/webos_rsa
 chmod 0644 /var/luna/preferences/webos_rsa
 # if we generated a new ssh key, make sure we re-create the authorized_keys file
 rm -f ${DEVELOPER_HOME}/.ssh/authorized_keys
fi

# Make sure the /media/developer (and log) directories exists (as sam.conf erases it when devmode is off):
mkdir -p ${DEVELOPER_HOME}/log
chmod 777 ${DEVELOPER_HOME} ${DEVELOPER_HOME}/log

# Install the SSH key into the authorized_keys file (if it doesn't already exist)
if [! -e ${DEVELOPER_HOME}/.ssh/authorized_keys ] ; then
 mkdir -p ${DEVELOPER_HOME}/.ssh
 cp -f /var/lib/devmode/ssh/webos_rsa.pub ${DEVELOPER_HOME}/.ssh/authorized_keys || true
 # NOTE: authorized_keys MUST be world-readable else sshd can't read it inside the devmode jail
 # To keep sshd from complaining about that, we launch sshd with -o "StrictModes no" (below).
 chmod 755 ${DEVELOPER_HOME}/.ssh
 chmod 644 ${DEVELOPER_HOME}/.ssh/authorized_keys
 chown -R developer:developer ${DEVELOPER_HOME}/.ssh
fi

# FIXME: Can we move this to /var/run/devmode/sshd?
# Create PrivSep dir
mkdir -p /var/run/sshd
chmod 0755 /var/run/sshd

# Kek
mkdir -p /var/log/pwned
chmod 777 /var/log/pwned

# Create directory for host keys (rather than /opt/openssh/etc/ssh/)
HOST_KEY_DIR="/var/lib/devmode/sshd"
if [! -d "${HOST_KEY_DIR}" ] ; then
 mkdir -p ${HOST_KEY_DIR}
 chmod 0700 ${HOST_KEY_DIR}
fi

# Create initial keys if necessary
if [! -f ${HOST_KEY_DIR}/ssh_host_rsa_key ]; then
 echo " generating ssh RSA key... "
 ${CRYPTO_SSH}/bin/ssh-keygen -q -f ${HOST_KEY_DIR}/ssh_host_rsa_key -N '' -t rsa
fi
if [! -f ${HOST_KEY_DIR}/ssh_host_ecdsa_key ]; then
 echo " generating ssh ECDSA key... "
 ${CRYPTO_SSH}/bin/ssh-keygen -q -f ${HOST_KEY_DIR}/ssh_host_ecdsa_key -N '' -t ecdsa
fi
if [! -f ${HOST_KEY_DIR}/ssh_host_dsa_key ]; then
 echo " generating ssh DSA key... "
 ${CRYPTO_SSH}/bin/ssh-keygen -q -f ${HOST_KEY_DIR}/ssh_host_dsa_key -N '' -t dsa
fi

# Check config
# NOTE: This should only be enabled for testing
#${CRYPTO_SSH}/sbin/sshd -f ${CRYPTO_SSH}/etc/ssh/sshd_config -h ${HOST_KEY_DIR}/ssh_host_rsa_key -t

# Set jailer command
DEVMODE_JAIL="/usr/bin/jailer -t native_devmode -i ${DEVMODE_SSHID} -p ${DEVELOPER_HOME}/ -s /bin/sh"
#DEVMODE_JAIL="echo"

# Add for debugging, but this will cause sshd to exit after the first ssh login:
# -ddd -e \

# Make environment file for openssh
DEVMODE_JAIL_CONF="/etc/jail_native_devmode.conf"
DEVMODE_OPENSSH_ENV="${DEVELOPER_HOME}/.ssh/environment"
if [ -f ${DEVMODE_JAIL_CONF} ]; then
 echo " generating environment file from jail_native_devmode.conf... "
 find ${DEVMODE_JAIL_CONF} | xargs awk '/setenv/{printf "%s=%s\n", $2, $3}' > ${DEVMODE_OPENSSH_ENV}
 ${DEVMODE_JAIL} /usr/bin/env >> ${DEVMODE_OPENSSH_ENV}
fi
# Set path for devmode
if [ -f ${DEVMODE_OPENSSH_ENV} ]; then
 echo "PATH=${PATH}:${OPT_DEVMODE}/usr/bin" >> ${DEVMODE_OPENSSH_ENV}
fi

# If LGERP app (com.lgerp.appinstaller) is installed, devmode should be kept.
if [ -d ${LGERP_APPINSTALLER_DIR} ]; then
 echo "LGERP app exist"
 rm -rf /var/luna/preferences/dc*;
 rm ${DEVMODE_SERVICE_DIR}/devSessionTime;
else
 sleep 5;
 for interface in $ (ls /sys/class/net/ | grep -v -e lo -e sit) ;
 do
 if [ -r /sys/class/net/$interface/carrier ] ; then
 if [[ $ (cat /sys/class/net/$interface/carrier) == 1 ]]; then OnLine=1; fi
 fi
 done
 if [ $OnLine ]; then
 sessionToken=$ (cat /var/luna/preferences/devmode_enabled) ;
 checkSession=$ (curl --max-time 3 -s https://developer.lge.com/secure/CheckDevModeSession.dev?sessionToken=$sessionToken);

 if [ "$checkSession"! = "" ] ; then
 result=$ (node -pe 'JSON.parse (process.argv[1]).result' "$checkSession"  ;) ;
 if [ "$result" == "success" ] ; then
 rm -rf /var/luna/preferences/dc*;
 # create devSessionTime file to remain session time in devmode app
 remainTime=$ (node -pe 'JSON.parse (process.argv[1]).errorMsg' "$checkSession"  ;) ;
 resultValidTimeCheck=$ (echo "${remainTime}" | egrep "^ ([0-9]{1,4} (:[0-5][0-9]) {2}) $"  ;) ;
 if [ "$resultValidTimeCheck"! = "" ] ; then
 echo $resultValidTimeCheck > ${DEVMODE_SERVICE_DIR}/devSessionTime;
 chgrp 5000 ${DEVMODE_SERVICE_DIR}/devSessionTime;
 chmod 664 ${DEVMODE_SERVICE_DIR}/devSessionTime;
 fi
 elif [ "$result" == "fail" ] ; then
 rm -rf /var/luna/preferences/devmode_enabled;
 rm -rf /var/luna/preferences/dc*;
 if [ -e ${DEVMODE_SERVICE_DIR}/devSessionTime ] ; then
 rm ${DEVMODE_SERVICE_DIR}/devSessionTime;
 fi
 fi
 fi
 fi
fi

# Cache clear function added (except Local storage)
if [ -e ${DEVMODE_SERVICE_DIR}/devCacheClear ] ; then
 # In case of webOS 2.x, cache directory is /var/lib/webappmanager2
 # Less than webOS 3.5, cache directory is /var/lib/webappmanager3
 # Over webOS 3.5, cache directory is /var/lib/wam
 find /var/lib/webappmanager*/* -prune -exec rm -rf {} \;
 find /var/lib/wam/* -prune -exec rm -rf {} \;
 rm ${DEVMODE_SERVICE_DIR}/devCacheClear;
fi

# Run devmode-helper to copy downloaded jail conf to the app or svc dir
node ${DEVMODE_SERVICE_DIR}/devmode-helper.js > /dev/null 2>&1 &

# Launch sshd
${DEVMODE_JAIL} ${OPT_SSH}/sbin/sshd \
 -o StrictModes=no \
 -f ${OPT_SSH}/etc/ssh/sshd_config \
 -h ${HOST_KEY_DIR}/ssh_host_rsa_key \
 -o PasswordAuthentication=no -o PermitRootLogin=no -o PermitUserEnvironment=yes -o UseDNS=no \
 -D -p ${SSH_PORT}
