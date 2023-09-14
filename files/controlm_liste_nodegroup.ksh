#!/bin/ksh

# application   : CONTROLM
# Name          : liste_nodegroups
# langage       : script ksh
# date creation : 27-FEB-2013
# version       :
# date version  :
# parametres    :
# auteur        : O.BRETHEAU
# sortie        : stdout
# DESCRIPION    : search Control server for a nodegroup
#


USAGE="Usage :  liste_nodegroups node_id"

RC=0
NODEGROUP=$1

if [ $# != 1 ] ; then
        echo ${USAGE}
	RC=1
else

	TEMPO="/tmp/liste_nodegroup_tempo_$$"
	TEMPO2="/tmp/liste_nodegroup_tempo2_$$"
	> ${TEMPO}
	> ${TEMPO2}
	ctmnodegrp -list |  egrep -v 'Application|==' | awk -F" " '{print $1,$2}'| sed '/^ $/d' > ${TEMPO}

	while read line
	do
		nodegroup=`echo $line| cut -f1 -d " "`
		appli=`echo $line| cut -f2  -d " "`
		ctmnodegrp -EDIT   -NODEGRP $nodegroup  -APPLTYPE $appli -view >> ${TEMPO2}
	done < ${TEMPO}


        cat ${TEMPO2} |grep -w "${NODEGROUP} " > /dev/null 2>&1
        if [ $? = 0 ]; then
                grep -w "${NODEGROUP} " ${TEMPO2} |awk '{ print $2}'
                /bin/rm -f  ${TEMPO}  ${TEMPO2}
                RC=0
        else
                echo "${NODEGROUP} not found ${TEMPO2}"
                RC=1
        fi

fi
exit $RC
