# Use on putput from 
# find -L / -type d \
# \( -path /dev -o -path /proc -o -path /run -o -path /sys -o -path /tmp -o -path "*/.Private" \) \
# -prune -o -print0 2>/dev/null | sudo xargs -0 stat -Lc "%a;%n;%F" 2>/dev/null 

BEGIN	{ 
	FS=";"
	if (depth == "") depth=2
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
	for (I in nodes) {
		if (I==1) {
			path=""
			continue
		}
		else
			path=path "/" nodes[I]
		leaves[path] += 1
		squawk("dirs: I=" I "\tpath=" path "\tleaves[path]=" leaves[path])
	rest[$2]=$0; sub(/^[^;]*;[^;]*;[^;]*;/,"",rest[$2])
	}
}

# When the input line describes anything not a directory
$3 !~ "directory" {
	types[$2]=$3		# capture the node type
	dir=substr($2, 1, match($2, /\/[^\/]*$/) -1)
	perm=( $1 > perms[dir] ? $1 : perms[dir] )
	squawk("files:\tfile=" $2 "\tdir=" dir "\tperms[dir]=" perms[dir] "\tperm=" perm)
	perms[dir]=perm
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
			if (K > N) {
				P=( props[J] > perms[J] ? props[J] : perms[J] )
				squawk("end:\tprops[J]=" props[J] "\tperms[J]=" perms[J])
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
		head=""; tail=""; P=0
		squawk("end: cleared")
	}
	# Report final results
	format="%s;%s;%s;%s;%s;%s\n"
	printf format, "_P", "_Perm", "_Prop", "_Type", "_Path", "_Other"
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
