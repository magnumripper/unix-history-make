#!/bin/bash


# When to remove reference files, because their contents are integrated
# into the distribution.  Using release/2.0 does not work, because this
# branch is bypassed on the way to 3.0.0.
# The following is a commit after 2.0 that is not bypassed by a merge on the
# road to 3.0.0
# It is marked ALPHA -> BETA and occurs at 785403528
REF_IMPORT_END=1e9b5066743a9ebe56ef60a9841f1ebd929dd78a

# Location of archive mirror
ARCHIVE=../archive

# Used to terminate when git fast-import fails
trap "exit 1" TERM
export TOP_PID=$$

# Git fast import
gfi()
{
	if [ -n "$DEBUG" ]
	then
		tee ../gfi.in
	else
		cat
	fi |
	git fast-import --stats --done --quiet || kill -s TERM $TOP_PID
}


# Branches that get merged
MERGED="BSD-4_4_Lite2 386BSD-0.1"

# Issue a git fast-import data command for the specified string
data()
{
	local LEN=$(echo "$1" | wc -c)
	echo "data $LEN"
	echo "$1"
}

cd import

echo "Adding merge and reference files" 1>&2
{
cat <<EOF
# Start FreeBSD commits
reset refs/heads/FreeBSD-release/2.0
commit refs/heads/FreeBSD-release/2.0
mark :1
author  Diomidis Spinellis <dds@FreeBSD.org> 739896552 +0000
committer  Diomidis Spinellis <dds@FreeBSD.org> 739896552 +0000
$(data "Start development on FreeBSD-release/2.0

Create reference copy of all prior development files")
merge BSD-4_4_Lite2
merge 386BSD-0.1
EOF
for ref in $MERGED ; do
	git ls-tree -r $ref |
	awk '{print "M", $1, $3, ".ref-'$ref'/" $4}'
done
cat <<EOF
reset refs/tags/FreeBSD-2.0-START
from :1
done
EOF
} | gfi

echo "Adding 2.0" 1>&2
{
	../git-massage.pl FreeBSD FreeBSD-2.0-START $ARCHIVE/freebsd.git/ --reverse --use-done-feature --progress=1000 $REF_IMPORT_END
	echo done
} | gfi

echo "Removing reference files" 1>&2
{
cat <<EOF
# Now remove reference files
commit refs/heads/FreeBSD-release/2.0
mark :1
author  Diomidis Spinellis <dds@FreeBSD.org> 785501938 +0000
committer  Diomidis Spinellis <dds@FreeBSD.org> 785501938 +0000
$(data "Remove reference files")
from refs/heads/FreeBSD-release/2.0^0
EOF
for ref in $MERGED ; do
	echo "D .ref-$ref/"
done
cat <<EOF
reset refs/tags/FreeBSD-2.0-END
from :1
done
EOF
} | gfi

echo "Adding remainder" 1>&2
# Add the remaining repo
# REF_REMAINING=$(cd $ARCHIVE/freebsd.git/ ; git branch -l | egrep -v 'projects/|user/|release/2\.0| master')\ HEAD
REF_REMAINING=$(cd $ARCHIVE/freebsd.git/ ; git branch -l | egrep -v 'projects/|user/|release/2\.0| master' | grep /3)
{
	../git-massage.pl FreeBSD FreeBSD-2.0-END $ARCHIVE/freebsd.git/ --reverse --use-done-feature --progress=1000 ^$REF_IMPORT_END $REF_REMAINING
	echo done
} | gfi
