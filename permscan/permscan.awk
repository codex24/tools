# permscan.awk: post-processor to report the most permissive file system
#   permissions of objects at or below a specified depth from root.
# Use on putput from:
#   find -L / \
#   \( -path /dev -o -path /proc -o -path /run \
#   -o -path /sys -o -path /tmp -o -path "*/.Private" \) \
#   -prune -o -print0 2>/dev/null \
#   | sudo xargs -0 stat -Lc ""%a;%n;%F;%U;%G;%s;%y" 2>/dev/null 
# That is, a list in ';'-delimited CSV format of attributes of all
#   file system objects in the system, less system virtual directories, 
#   that includes the following fields.
# Expected order of fields in the input records:
#   $1: Object's permissions in octal 
#   $2: object's fully qualified path name
#   $3: Object's file type (regular [empty] file, directory, socket, etc.)
#   $4: Object's owner (this and following fields are handled in one group,
#           and may be modified from the calling pipeline)
#   $5: Object's group
#   $6: Object's size in bytes
#   $7: Object's date & time of Object's last modififcation
# Output is a similar list in ';'-delimited CSV format of the same 
#   input attributes of just directories from the root down to the
#   depth specified (default 2). The output attributes are the same
#       as the input with the additions of two values:
#   field 1: a flag (""|"*") indicating which objects have some
#       decendant with more permissive permission (added)
#   field 2: object's permissions in octal ($1 in input)
#   field 3: object's most permissive decendant's permission (added)
#   field 4: object's fully qualified path name ($2 in input)
#   field 5: object's file type ($3 in input)
#   field 6: object's owner (this and following fields are handled in one group,
#           and may be modified from the calling pipeline) ($4 in input)
#   field 7: object's group ($5 in input)
#   field 8: object's size in bytes ($6 in input)
#   field 9: object's date & time of Object's last modififcation ($7 in input)
# Descriptions of arrays used:
#   types: names of object types, indexed by path
#   perms: object file system permissions, indexed by path
#   props: greatest propogated permissions from childen, indexed by path
#   leaves: counts of path references where 1=>leaf, indexed by path
#   leafsort: verified & sorted copy of leaves, indexed by 1-based integers
#   nodes: temporary holder for path elements, indexed by 1-based integers
#   rest: the remainder of the input data for an object after $3, indexed by path

# Initialization ("begin:")
BEGIN	{ 
	FS=";"  # CSV format using delimiter ';', as some file names contain ','
	if ("DBUG" in ENVIRON) DBUG=ENVIRON["DBUG"] # capture debugging level
	# set default or adjust passed reporting depth
	if (! depth)    depth=3 	# default, equivalent to "find / -depth 2 ..."
	else            depth+=1	# find depth n => split tokens n+1
	squawk("begin:\tdepth=" depth "\tDBUG=" DBUG, 1)
}

# For every line in input ("every:")
#   As all objects are encountered in input, capture:
#   the actual permissions of this object,
#   the initial value for a propogated descendant permission,
#   the object type of this object.
{
	perms[$2]=$1	# Value of local permissions
	props[$2]=$1	# Initial value of propogated permissions
	types[$2]=$3	# capture the object type
	squawk("every:\tpath=" $2 "\tperms[path]=" $1, 1)
}

# When the input line describes a directory ("dirs:")
#   As directories are encountered in input, a count is incremented
#   for each parent path from root down to identify leaf directories.
$3 ~ "directory" {
	# increment counts for each path element
	split($2,nodes,"/")	# split the directory name into nodes
	for (I in nodes) {
		if (I==1) {     # root special case
			path=""     # path is null for accumulation
			continue    # no further processing
		} else	path=path "/" nodes[I]  # accumulate path to count
		leaves[path] += 1   # increment the visit count for this path
		squawk("dirs:\tI=" I "\tpath=" path "\tleaves[path]=" leaves[path], 2)
	}
    # capture remaining fields as single value
    rest[$2]=$0; sub(/^[^;]*;[^;]*;[^;]*;/,"",rest[$2])
    squawk("dirs:\trest=" rest[$2], 1)
}

# When the input line describes anything not a directory ("files:")
#   As files are encountered in input, their permissions are
#   propogated to their parent directory's propogation entry.
$3 !~ "directory" {
    # propogate the object's permissions to its host directory
    dir=substr($2, 1, match($2, /\/[^\/]*$/) -1)    # crop the path to this
	perm=laxest($1, props[dir])     # accumulate file permissions
	squawk("files:\tfile=" $2 "\tdir=" dir "\tprops[dir]=" props[dir] "\tperm=" perm, 1)
	props[dir]=perm # capture computed permission value to host propogation entry
	# capture remaining fields as single value
	rest[$2]=$0; sub(/^[^;]*;[^;]*;[^;]*;/,"",rest[$2])
    squawk("files:\trest=" rest[$2], 1)
}

# Digest and report ("end:")
#   Output report contains only directories.
#   Ensure the contents of leaves are true leaf directories,
#   propogate their permissions up the tree to the root,
#   and then produce output for depth level of directories.
END {
	if ("/" in leaves) leaves["/"]=1    # root is a special case
    J=0     # initialize serialization index
	# prune out the non-leaves, complete pruning before scan
	for (I in leaves) {
        # I is a path
		if (leaves[I] != 1) continue    # no futher processing if not leaf
        leafsort[++J]=I     # serialize the leaves
        squawk("loop I:\tI=" I "\tJ=" J \
            " \tleafsort[J]=" leafsort[J] "\tleaves[I]=" leaves[I], 2)
    }
    leafsort[0]=asort(leafsort)   # sort the serialized leaves, keep count in 0th index
    squawk("end:\tleaves verified and serialized to leafsort", 1)

	# leafsort contains verified leaf directory paths in values, indexed in sort order
	# rescan the true leaves to propogate the most permissive permissions upstream
	for (J=1; J<=leafsort[0]; J++) {
        # split the directory name into nodes disregarding first, keep count of elements in N
		N=split(substr(leafsort[J], 2), nodes, "/")
		squawk("end:\tJ=" J "\tleafsort[J]=" leafsort[J]"\tprops[leafsort[J]]=" \
            props[leafsort[J]] "\tN=" N "\tnodes[1]=" nodes[1] "\tnodes[N]=" nodes[N], 2)
	    # propogate permissions for the paths from root to each path element
		for ( K=N; K>=1; K-- ) {	# scan the path from right to left
			squawk("loop K:\tK=" K " \tnodes[K]=" nodes[K], 2)
            # parent is built up rather than matched, due to specials embedded in path names
            for (L=1; L<K; L++) {
			    parent=parent "/" nodes[L] # append this path element to accumulated path parent
                squawk("loop L:\tparent=" parent "\tnodes[L]=" nodes[L], 2)
            }
            # child is accumulated
			child=parent "/" nodes[K] 
			squawk("loop K:\tparent=" parent "\tchild=" child, 2)
            # compare propogated permissions of parent to those of child 
			perm=laxest(props[parent], props[child]) 
		    props[parent]=perm	# write greatest permission into parent's propogation entry
			squawk("loop K:\tprops[parent]=" props[parent] \
                "\tprops[child]=" props[child] "\tperm=" perm, 2)
		    # reset iterators at end of loop
    		parent=""; child=""; perm=0
		}
		squawk("end: cleared", 2)
	}
    squawk("end:\tleaves propogated", 1)

	# report final results
	format="%s;%s;%s;%s;%s;%s\n"	# a printf format string
	# output header row, values prefixed with space to sort to top
	printf format,
		" Over-permissive?",
		" Permission for this object",
		" Most permissive child",
		" Object type",
		" Object path",
		" Other object attributes"
	# for all paths in input, consider for output
	for (M in perms) {
		if (M == "") continue	# for root special case
		# if this path is a directory, then output and is within top depth specfication
		if ( types[M] == "directory" && split(M,nodes,"/") <= depth )
            # then print the formatted output 
			printf format,  
                ( props[M] > perms[M] ? "*" : "" ),
                perms[M],
                props[M],
                types[M],
                M,
                rest[M]
	}
	squawk("end: done", 1)
}

# Local Functions
# Function to emit messages only when debugging is active
function squawk (string, sev) {
    # string: string to print; sev: an optional debug severity level
    # if the current debugging level is at or above
    # the severity of the proposed message, then emit the message.
    #   sev 0 should always emit.
    #   sev 1 is base level messages
    #   sev 2 is messages from within control stuctures
    #   sev 3 is messages from function calls
    if (! sev)  sev=1   # default severity if not provided
	if (DBUG >= sev) print string " (" sev ")" > "/dev/stderr"
}

# Function to do permission comparisons
function laxest (A, B,      C) {
    # A, B: parameters, C: local var
    # in parms, move 4th digit to end to make most significant
    if (length(A) == 4) A=substr(A,2,3) substr(A,1,1) 
    if (length(B) == 4) B=substr(B,2,3) substr(B,1,1) 
	# compare parms with reversed order of digits so widest scope value is most significant
    C=( reverse(A) > reverse(B) ? A : B )	# find greatest permission
    # if 4th digit present, move back where it belongs
    if (length(C) == 4) C=substr(C,4,1) substr(C,1,3)
    squawk("laxest:\tof " A " and " B " is " C, 3)
	return C    # return greatest permission
}

# Function to reverse the characters in a string
function reverse(fore,     back) {    
    # fore: parameter, back: local var
    for (I=1; I<=length(fore); I++)
        back=substr(fore,I,1) back  # accumulate the reversed string
    squawk("reverse:\tof " fore " is " back, 3)
    return back     # return reversed string
}

#eof
