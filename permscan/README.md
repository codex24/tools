# scanperm

This utility scans a host's file system and produces a report that lists the files 
and directories, their permissions, and the most permissive permissions of any object
below them in the file system heirarchy.

## Uses
The two use cases for this utility are:
* Immediately identify any situations where a parent directory has a child with more permissive filesystem permissions than itself.
* Over time, identify filesystem permissions that change through iterative comparison of output.

## Description
The artifacts that implement this utility are checked into [github:chatid/terraform-prosody/tools/permscan/](https://github.com/chatid/terraform-prosody/tree/DEVO-98/tools/permscan).

### Artifacts
The utility is provided as two artifacts:
* permscan: a BASH shell script and entry point
* permscan.awk: an AWK script that performs the post-processing

The shell script is the only part that the user or system should need to touch, besides output. 
The utility produces output in the host's _/tmp_ directory.

### Installation
The shell script and the AWK script should be installed in the same directory as the shell script expect to find the AWK script there, but where that directory is located is irrelevant. On an **Debian or Ubuntu** system, the expected directory would be _/usr/local/bin_.
For example:
```
$ git clone git@github.com:chatid/terraform-prosody.git /tmp/terraform-prosody
$ sudo install /tmp/terraform-prosody/tools/permscan/* /usr/local/bin
$ rm -rf /tmp/terraform-prosody
```
### Invocation
The utility is designed to be run repeatedly, e.g. by a cron job, putting output into the host's _/tmp_ directory. 

> permscan [-d N]

It only has one parameter, which is optional, to specify the depth into the file system for reporting. 
The default for that value on 'N' is "2", which implies paths of the form, "/x/y".

### Using Results
The output file, with a file path of `/tmp/permscan-<YYYYMMDD>:<hhmmss>.csv`
is in Comma Separated Values format with semi-colons (';') as separators.
The tail portion of the file name is the timestamp of invocation, where 
- YYYY: year
- MM: 0-padded month
- DD: 0-padded day-of-month
- hh: 0-padded 24 hour format hour-of-day
- mm: 0-padded minutes
- ss: 0-padded seconds

Example content:
```
Over-permissive?; Permission for this object; Most permissive child; Object type; Object Path; Other Object Attributes
;1204;1204;regular file;/etc/aliases;root;root;238;2017-06-21 16:24:12.949933999 +0000
*;1204;755;directory;/etc;root;root;4096;2017-06-21 16:26:32.220497000 +0000
;1777;1777;directory;/var/crash;root;root;4096;2017-05-15 14:18:44.861531320 +0000
;1777;1777;directory;/var/lock;root;root;80;2017-06-22 16:09:11.648000000 +0000
;1777;1777;directory;/var/tmp;root;root;4096;2017-06-21 16:22:19.349164312 +0000
*;2555;755;directory;/usr/sbin;root;root;4096;2017-06-21 16:24:55.066410599 +0000
;2755;2755;regular file;/sbin/pam_extrausers_chkpwd;root;shadow;35632;2016-03-16 18:12:32.000000000 +0000
;2755;2755;regular file;/sbin/unix_chkpwd;root;shadow;35600;2016-03-16 18:12:32.000000000 +0000
*;2755;755;directory;/etc/alternatives;root;root;4096;2017-06-21 16:26:25.016896999 +0000
;2775;2775;directory;/var/local;root;staff;4096;2016-04-12 20:14:23.000000000 +0000
```
**Please note:** The first line of the file is a column header line, not live data.

#### Direct Viewing
This content can be read and parsed by any spread sheet tool that can read CSV data, including,
* Excel (Windows & Mac)
* LibreOffice Calc (Linux)
* Google Sheets (web)

Be sure to freeze the header line in the viewer app before attempting to sort any columns.

#### Iterative Comparison
Utility results may be compared via 'diff' or visual diff tools, as the output is sorted on the path field and is deterministically ordered.
For example:
```
$ ll permscan-*
-rw-rw-r-- 1 kevin kevin     83160 Jun 22 13:23 permscan-20170622:132256.csv
-rw-rw-r-- 1 kevin kevin     83160 Jun 22 13:26 permscan-20170622:132556.csv
-rw-rw-r-- 1 kevin kevin 116880720 Jun 22 13:26 permscan-init-20170622:132556.csv
kevin@carnaro:/tmp 
$ diff permscan-20170622:132256.csv permscan-20170622:132556.csv
377c377
< ;444;444;regular empty file;/etc/mtab;root;root;0;2017-06-22 13:23:08.399967444 -0500
---
> ;444;444;regular empty file;/etc/mtab;root;root;0;2017-06-22 13:26:09.187972897 -0500
497c497
< ;644;644;regular file;/etc/wgetrc;root;root;4942;2016-06-14 03:18:07.000000000 -0500
---
> ;664;664;regular file;/etc/wgetrc;root;root;4942;2016-06-14 03:18:07.000000000 -0500
939c939
< ;1777;1777;directory;/var/tmp;root;root;4096;2017-06-22 13:22:52.755966973 -0500
---
> ;1777;1777;directory;/var/tmp;root;root;4096;2017-06-22 13:25:27.727971646 -0500
```

___
<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">
<img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/80x15.png" /></a>
<br />This work is licensed under a 
<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">
Creative Commons Attribution-ShareAlike 4.0 International License</a>.
