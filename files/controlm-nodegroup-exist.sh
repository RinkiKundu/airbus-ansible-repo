#!/bin/csh
set NODEGROUP = $1
ctmnodegrp -LIST ALL | grep -w $NODEGROUP  >/dev/null
if ( $status == 0 ) then
        hostname
	exit 0
endif
exit 1
