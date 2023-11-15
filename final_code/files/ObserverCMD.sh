#!/bin/bash
# set oracle environment
set -x
SCRIPT=$1
ORA_SID=$2
su - oracle -c "[ -f .bash_profile ] && . .bash_profile; [ -f .profile ] && . .profile ;cd OBSERVER; ./${SCRIPT} ${ORA_SID}"
exit $?
