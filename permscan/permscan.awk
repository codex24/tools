#!/bin/bash
# permscan: scan file system and report submerged permissive files

# Init
NOW=$(date "+%Y%m%d:%H%M%S")
THIS=$(readlink -e $0)
HERE=${THIS%/*}
while getopts "hd:" opt; do
	case $opt in
		d)
			depth=$OPTARG ;;
		h)
			echo "permscan [-d N]"
			exit 1 ;;
		*)
			echo "Invalid option: -$OPTARG" >&2 ;;
	esac
done

# Check for sudo access
if [[ $(id -u 2>/dev/null 1>&2) -eq 0 \
   || $(id -Gn 2>/dev/null 1>&2 | grep -q sudo) ]]
then
	echo "permscan has sudo access at $NOW."
else {
	echo "permscan needs sudo access."
	exit 2
} fi

# Initial scann of full file system
echo "permscan initial scan:"
sudo find -L / -type d \( \
-path /dev -o \
-path /proc -o \
-path /run -o \
-path /sys -o \
-path /tmp -o \
-path "*/.Private" \
\) -prune -o -print0 2>/dev/null \
| sudo xargs -0 stat -Lc "%a;%n;%F;%U;%G;%s;%y" \
>/tmp/permscan-init-$NOW.csv 2>/dev/null

# Post-process scan for permission propogation and output
echo "permscan postprocessing (depth ${depth:-3}):"
awk ${depth:+-v depth=${depth}} -f ${HERE}/permscan.awk /tmp/permscan-init-${NOW}.csv \
>/tmp/permscan-${NOW}.csv \
&& echo "Created: /tmp/permscan-${NOW}.csv" \
|| echo "Not created: /tmp/permscan-${NOW}.csv ($?)"
#| sort -n -t';' -k5 >/tmp/permscan-${NOW}.csv \

#eof
