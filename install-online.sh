#!/system/bin/sh
#
# $id Online Installer
# https://raw.githubusercontent.com/VR-25/$id/$commit/install-online.sh
#
# Copyright 2019-2024, VR25
# License: GPLv3+
#
# Usage: sh install-online.sh [-c|--changelog] [-f|--force] [-n|--non-interactive] [%parent install dir%] [commit]


set +x
echo
id=acc
domain=vr25
data_dir=/data/adb/$domain/${id}-data

# log
[ -z "${LINENO-}" ] || export PS4='$LINENO: '
mkdir -p $data_dir/logs
set -x &>$data_dir/logs/install-online.sh.log

trap 'e=$?; echo; exit $e' EXIT


# set up busybox
#BB#
bin_dir=/data/adb/vr25/bin
busybox_dir=/dev/.vr25/busybox
magisk_busybox="$(ls /data/adb/*/bin/busybox /data/adb/magisk/busybox 2>/dev/null || :)"
[ -x $busybox_dir/ls ] || {
  mkdir -p $busybox_dir
  chmod 0755 $busybox_dir $bin_dir/busybox 2>/dev/null || :
  for f in $bin_dir/busybox $magisk_busybox /system/*bin/busybox*; do
    [ -x $f ] && eval $f --install -s $busybox_dir/ && break || :
  done
  [ -x $busybox_dir/ls ] || {
    echo "Install busybox or simply place it in $bin_dir/"
    echo
    exit 3
  }
}
case $PATH in
  $bin_dir:*) ;;
  *) export PATH="$bin_dir:$busybox_dir:$PATH";;
esac
unset f bin_dir busybox_dir magisk_busybox
#/BB#


# root check
[ $(id -u) -ne 0 ] && {
  echo "$0 must run as root (su)"
  exit 4
}


set -eu
get_ver() { sed -n 's/^versionCode=//p' ${1:-}; }


! test -f /data/adb/vr25/bin/curl || {
  test -x /data/adb/vr25/bin/curl \
    || chmod -R 0755 /data/adb/vr25/bin
}


set_dl() {
  if [ ".${1-}" != .wget ] && i=$(which curl) && [ ".$(head -n 1 ${i:-//} 2>/dev/null || :)" != ".#!/system/bin/sh" ]; then
    curl --help | grep '\-\-dns\-servers' >/dev/null && dns="--dns-servers 9.9.9.9,1.1.1.1" || dns=
    _curl() {
      curl $dns --progress-bar --insecure -L "$@" || { set_dl wget; _curl "$@"; }
    }
  else
    _curl() {
      shift $(($# - 1))
      PATH=${PATH#*/busybox:} /dev/.vr25/busybox/wget -O - --no-check-certificate $1
    }
  fi
}

set_dl


commit=$(echo "$*" | sed -E 's/%.*%|-c|--changelog|-f|--force|-n|--non-interactive| //g')
: ${commit:=master}

tarball=https://github.com/VR-25/$id/archive/${commit}.tar.gz

installedVersion=$(get_ver /data/adb/$domain/$id/module.prop 2>/dev/null || :)

onlineVersion=$(_curl https://raw.githubusercontent.com/VR-25/$id/${commit}/module.prop | get_ver)


[ -f $PWD/${0##*/} ] || cd $(readlink -f ${0%/*})
[ -z "${reference-}" ] || cd /dev/.$domain/$id
rm -rf "./${id}-*/" 2>/dev/null || :


if [ ${installedVersion:-0} -lt ${onlineVersion:-0} ] \
  || case "$*" in *-f*|*--force*) true;; *) false;; esac
then

  ! echo "$@" | grep -Eq '\-\-changelog|\-c' || {
    if echo "$@" | grep -Eq '\-\-non-interactive|\-n'; then
      echo $onlineVersion
      echo "https://github.com/VR-25/$id/blob/${commit}/changelog.md"
      exit 5 # no update available
    else
      echo
      print_available $id $onlineVersion 2>/dev/null \
        || echo "$id $onlineVersion is available"
      print_install_prompt 2>/dev/null \
        || echo -n "- Download and install? ([enter]: yes, CTRL-C: no) "
      read REPLY
    fi
  }

  # download and install tarball
  : ${installDir:=$(echo "$@" | sed -E "s/-c|--changelog|-f|--force|-n|--non-interactive|%|$commit| //g")}
  export installDir
  set +eu
  trap - EXIT
  echo
  _curl $tarball | tar -xz \
    && ash ${id}-*/install.sh

else
  echo
  print_no_update 2>/dev/null || echo "No update available"
  exit 6
fi


set -eu
rm -rf "./${id}-*/" 2>/dev/null
exit 0
