# dnif
## Description
From [Stack Overflow](https://stackoverflow.com/a/24642735/638042):
"dnif" is a BASH shell function which will search for a name you provide as a parameter in each directory upwards from the current to the root, and if found, list it with 'ls' and the optional ls -options that you provide. 
Example output:

```
me@host:~/dev/example
$ dnif; echo $?
dnif [ls-opts] name
1
me@host:~/dev/example
$ dnif -alp nonesuch; echo $?
2
me@host:~/dev/example
$ $ dnif -alp .bashrc; echo $?
-rw-r--r-- 1 me mine 3486 Apr  3  2012 /home/me/.bashrc
0
me@host:~/dev/example
$ dnif -d .
/home/me/dev/example/.
/home/me/dev/.
/home/me/.
/home/.
/.
```

## Installation

Extract the included file "dnif.sh" and source into the current shell.
This can be accomplished automatically for every shell instance by placing the file in your ```~/rc.d``` directory (if so configured).


## Notes

"dnif" is "find" backwards.
The function is a finite loop (not recursive), creates no subshells, and uses Bash built-ins as much as possible for speed.

All hits at each ascending directory level are listed.

The ls -opts are optional, but must precede the required search argument.

The search argument may be a file or directory.

If the search argument is a directory, include the ls -opt '-d' to restrict the results to directory names rather than contents.

The function returns exit code
* 0 if there is at least one hit,
* 1 if no parameters are provided for help, and
* 2 if nothing is found.
