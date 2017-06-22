# permscan.awk: post-processor to report the most permissive file system
#   permissions of objects at or below a specified depth from root.
# Use on putput from:
#   find -L / -type d \
#   \( -path /dev -o -path /proc -o -path /run \
#   -o -path /sys -o -path /tmp -o -path "*/.Private" \) \
#   -prune -o -print0 2>/dev/null \
#   | sudo xargs -0 stat -Lc ""%a;%n;%F;%U;%G;%s;%y" 2>/dev/null 
# Expected order of fields in the input records:
#   $1: Object's permissions in octal 
#   $2: object's fully qualified path name
#   $3: Object's file type (regular [empty] file, directory, socket, etc.)
#   $4: Object's owner (this and following fields are handled in one group)
#   $5: Object's group
#   $6: Object's size in bytes
#   $7: Object's date & time of Object's last modififcation
# Descriptions of arrays used:
#   types: names of object types, indexed by path
#   perms: object file system permissions, indexed by path
#   props: greatest propogated permissions from childen, indexed by path
#   leaves: counts of path references where 1=>leaf, indexed by path
#   nodes: temporary holder for path elements, indexed by 1-based ascending integers

BEGIN	{ 
	FS=";"
	# set default reporting depth: find depth n => split tokens n+1
	if (depth == "") 
		depth=3
	else
		depth+=1
}

# For every line in input
{
	perms[$2]=$1	# Value of local permissions
	props[$2]=$1	# Initial value of propogated permissions
	squawk("every:\tpath=" $2 "\tperms[path]=" $1)
}

# When the input line describes a directory
$3 ~ "directory" {
	types[$2]=$3		# capture the node type
	split($2,nodes,"/")	# split the directory name into nodes
	# increment counts for each path element
	for (I in nodes) {
		if (I==1) {
			path=""
			continue
		}
		else	path=path "/" nodes[I]
		leaves[path] += 1
		squawk("dirs: I=" I "\tpath=" path "\tleaves[path]=" leaves[path])
		# Capture remaining fields as single value
		rest[$2]=$0; sub(/^[^;]*;[^;]*;[^;]*;/,"",rest[$2])
	}
}

# When the input line describes anything not a directory
$3 !~ "directory" {
	types[$2]=$3		# capture the node type
	dir=substr($2, 1, match($2, /\/[^\/]*$/) -1)
	# Accumulate greatest file permissions
	perm=( $1 > perms[dir] ? $1 : perms[dir] )
	squawk("files:\tfile=" $2 "\tdir=" dir "\tperms[dir]=" perms[dir] "\tperm=" perm)
	perms[dir]=perm # capture computed permission value
	# Capture remaining fields as single value
	rest[$2]=$0; sub(/^[^;]*;[^;]*;[^;]*;/,"",rest[$2])
}

# Digest and report
END {
	# root is  a special case
	if ("/" in leaves)
		leaves["/"]=0
	# prune out the non-leaves, complete pruning before scan
	for (I in leaves) 
		if (leaves[I] != 1) delete leaves[I]
	# rescan the true leaves to propogate the most permissive permissions upstream
	for (J in leaves) {
		squawk("end:\tJ=" J "\tprops[J]=" props[J])
		N=split(J,nodes,"/")	# split the directory name into nodes
		for (K=N+1; K>1; K-- ) {	# scan the path from right to left
			squawk("end:\tK=" K)
			# if looking at the object itself			
			if (K > N) {
				P=( props[J] > perms[J] ? props[J] : perms[J] )
				squawk("end:\tprops[J]=" props[J] "\tperms[J]=" perms[J])
			# if looking at the object's directory path
			} else {
				tail="/" nodes[K] tail
				head=substr(J, 1, match(J, /tail$/)-1)
				squawk("end:\thead=" head "\ttail=" tail)
				P=( props[head] > props[head "/" nodes[K]] ? props[head] : props[head "/" nodes[K]] )
				squawk("end:\tprops[head]=" props[head])
				squawk("end:\tprops[head/nodes[K]]=" props[head "/" nodes[K]])
			}
			squawk("end:\tP=" P)
			props[head]=P
			squawk("end:\tprops[head]=" props[head])
		}
		# reset iterators at end of loop
		head=""; tail=""; P=0
		squawk("end: cleared")
	}
	# Report final results
	format="%s;%s;%s;%s;%s;%s\n"
	printf format, " Over-permissive?", " Permission for this object", " Most permissive child", " Object type", " Object Path", " Other Object Attributes"
	for (L in perms) {
		if (L == "") continue	# for root special case
		# if this line is within top depth specfication, then output
		if (split(L,nodes,"/") <= depth)
			printf format, ( perms[L] == props[L] ? "" : "*" ), perms[L], props[L], types[L], L, rest[L]
	}
	squawk("end: done")
}

function squawk (string) {
	if ("DBUG" in ENVIRON)
		print string > "/dev/stderr"
}

#eof
