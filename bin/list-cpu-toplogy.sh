#!/bin/bash
SCRIPTDIR=`cd "$DIRNAME" && pwd`

# Read list of nodes
while read tmp NID tmp tmp tmp; do
	if [ "$NODES" = "" ]; then
		NODES="$NODES $NID"
	else
		NODES="$NID"
	fi
done <<< "$(numactl --hardware | grep "size:")"

declare -a SEEN
for NODE in $NODES; do
	SOCKET=0
	CPUS=`numactl --hardware | grep "node $NODE cpus:" | awk -F : '{print $2}' | sed -e 's/^\s*//'`
	for CPU in $CPUS; do
		CORE=0
		for CORE_SIBLING in $CPU `$SCRIPTDIR/list-cpu-siblings.pl $CPU cores | sed -e 's/,/ /g'`; do
			THREAD=0
			if [ "${SEEN[$CORE_SIBLING]}" != "yes" ]; then
				echo node $NODE socket $SOCKET core $CORE thread $THREAD cpu $CORE_SIBLING
				SEEN[$CORE_SIBLING]=yes
			fi

			for THREAD_SIBLING in `$SCRIPTDIR/list-cpu-siblings.pl $CORE_SIBLING threads | sed -e 's/,/ /g'`; do
				if [ "${SEEN[$THREAD_SIBLING]}" != "yes" ]; then
					THREAD=$((THREAD+1))
					echo node $NODE socket $SOCKET core $CORE thread $THREAD cpu $THREAD_SIBLING
					SEEN[$THREAD_SIBLING]=yes
				fi
			done
			CORE=$((CORE+1))
		done
		SOCKET=$((SOCKET+1))
	done
done