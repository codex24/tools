# permscan

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

The utility produces several informational messages as it runs, which are sent to stderr.
When run in a CLI pipeline, it produces the name of the output file on stdout so that subsequient commands may access that name directly.

```
$ ./permscan
permscan has sudo access at 20170627:153041.
permscan initial scan:
permscan postprocessing (depth 2):
Created: /tmp/permscan-20170627:153041.csv
$ ./permscan 2>/dev/null | od -a
0000000   /   t   m   p   /   p   e   r   m   s   c   a   n   -   2   0
0000020   1   7   0   6   2   7   :   1   5   3   3   0   3   .   c   s
0000040   v  nl
0000042
```

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
;755;755;directory;/;root;root;4096;2017-06-22 08:40:38.396003884 -0500
*;4755;755;directory;/bin;root;root;4096;2017-05-20 14:49:42.690145159 -0500
;700;700;directory;/boot/efi;root;root;4096;1969-12-31 18:00:00.000000000 -0600
;755;755;directory;/boot/grub;root;root;1024;2017-06-22 08:41:20.000000000 -0500
;700;700;directory;/boot/lost+found;root;root;12288;2016-12-28 19:12:46.000000000 -0600
;755;755;directory;/boot;root;root;3072;2017-06-22 08:41:18.000000000 -0500
;755;755;directory;/cdrom;root;root;4096;2016-12-28 19:18:54.635830246 -0600
;700;700;directory;/etc/.git;root;root;4096;2017-06-22 08:44:06.044012426 -0500
;755;755;directory;/etc/.java;root;root;4096;2017-05-03 14:50:05.591640858 -0500
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
-rw-rw-r-- 1 kevin kevin     24325 Jun 22 14:02 permscan-20170622:140129.csv
-rw-rw-r-- 1 kevin kevin     24325 Jun 22 15:16 permscan-20170622:151513.csv
-rw-rw-r-- 1 kevin kevin 117006812 Jun 22 15:15 permscan-init-20170622:151513.csv
$ diff permscan-20170622:140129.csv permscan-20170622:151513.csv
46c46
< ;755;755;directory;/etc/cups;root;lp;4096;2017-06-22 13:58:39.504031713 -0500
---
> ;755;755;directory;/etc/cups;root;lp;4096;2017-06-22 15:09:28.108096839 -0500
192c192
< *;775;700;directory;/home/kevin;kevin;kevin;16384;2017-06-22 14:01:10.956036281 -0500
---
> *;775;700;directory;/home/kevin;kevin;kevin;16384;2017-06-22 15:09:45.668097368 -0500
278c278
< ;3777;3777;directory;/var/crash;root;whoopsie;4096;2017-06-22 08:44:50.040014236 -0500
---
> ;3777;3777;directory;/var/crash;root;whoopsie;4096;2017-06-22 14:03:25.548000077 -0500
287c287
< ;755;755;directory;/var/run;root;root;1420;2017-06-22 11:14:32.547734754 -0500
---
> ;755;755;directory;/var/run;root;root;1420;2017-06-22 14:16:03.420000194 -0500
290c290
< ;1777;1777;directory;/var/tmp;root;root;4096;2017-06-22 14:01:32.736036937 -0500
---
> ;1777;1777;directory;/var/tmp;root;root;4096;2017-06-22 15:15:02.820106933 -0500
```
