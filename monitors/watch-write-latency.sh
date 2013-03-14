#!/bin/bash
# This monitor writes a file in a continual loop recording the latency
# of a write. Certain applications, including terminals, can stall if
# they are not allowed to complete a small write
# 
# (c) Mel Gorman 2013

# Extract the writer program
TEMPFILE=`mktemp`
LINECOUNT=`wc -l $0 | awk '{print $1}'`
CSTART=`grep -n "BEGIN C FILE" $0 | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$CSTART)) $0 | grep -v "^###" > $TEMPFILE.c

# Build it
WRITESIZE=
WRITEPAUSE=
BUILDRAND=
COUNT=100
IBS=1048576
if [ "$MONITOR_WRITE_LATENCY_RANDOM" = "yes" ]; then
	BUILDRAND=-DRANDWRITE
fi
if [ "$MONITOR_WRITE_LATENCY_WRITESIZE_MB" != "" ]; then
        IBS=$((MONITOR_WRITE_LATENCY_WRITESIZE_MB*1048576))
        WRITESIZE="-DBUFFER_SIZE=$IBS"

	# Bit arbitrary
	if [ $MONITOR_WRITE_LATENCY_WRITESIZE_MB -gt 16 ]; then
		COUNT=10
	fi
fi
if [ "$MONITOR_WRITE_LATENCY_WRITEPAUSE_MS" != "" ]; then
	WRITEPAUSE="-DBETWEENWRITE_PAUSE_MS=$MONITOR_WRITE_LATENCY_WRITEPAUSE_MS"
fi

gcc $BUILDRAND $WRITESIZE $WRITEPAUSE -O2 $TEMPFILE.c -o $TEMPFILE || exit -1

# Build a file on local storage for the program to access
dd if=/dev/zero of=monitor_writefile ibs=$IBS count=$COUNT > /dev/null 2> /dev/null

# Start the writer
$TEMPFILE monitor_writefile &
WRITER_PID=$!

# Handle being shutdown
EXITING=0
shutdown_write() {
	kill -9 $WRITER_PID
	rm $TEMPFILE
	rm -f monitor_writefile
	EXITING=1
	exit 0
}
	
trap shutdown_write SIGTERM
trap shutdown_write SIGINT

while [ 1 ]; do
	sleep 5

	# Check if we should shutdown
	if [ $EXITING -eq 1 ]; then
		exit 0
	fi

	# Check if the writer program exited abnormally
	ps -p $WRITER_PID > /dev/null
	if [ $? -ne 0 ]; then
		echo Writer program exited abnormally
		exit -1
	fi
done


==== BEGIN C FILE ====
#define _GNU_SOURCE
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>

#ifndef BUFFER_SIZE
#define BUFFER_SIZE (1048576UL)		/* Buffer to write data into */
#endif
#ifndef BETWEENWRITE_PAUSE_MS
#define BETWEENWRITE_PAUSE_MS 1500
#endif

int main(int argc, char **argv)
{
	int fd;
	struct stat stat_buf;
	off_t filesize;
	off_t slots;
	char *buf;

	if (argc < 2) {
		fprintf(stderr, "Usage: watch-write-latency <file>\n");
		exit(EXIT_FAILURE);
	}

	/* Allocate the buffer to write from */
	buf = malloc(BUFFER_SIZE);
	if (buf == NULL) {
		fprintf(stderr, "Buffer allocation failed");
		exit(EXIT_FAILURE);
	}
	memset(buf, 1, BUFFER_SIZE);

	/* Open file for writing */
	fd = open(argv[1], O_WRONLY);
	if (fd == -1) {
		perror("open");
		exit(EXIT_FAILURE);
	}

	/* Get the length stat */
	if (fstat(fd, &stat_buf) == -1) {
		perror("fstat");
		exit(EXIT_FAILURE);
	}
	filesize = stat_buf.st_size & ~(BUFFER_SIZE-1);
	slots = filesize / BUFFER_SIZE;

	/* Write until interrupted */
	while (1) {
		ssize_t position;
		ssize_t bytes_write;
		ssize_t slots_write;
		struct timeval start, end, latency;

		/* Seek to the start of the file */
		position = 0;
		slots_write = 0;
		if (lseek(fd, position, SEEK_SET) != position) {
			perror("lseek");
			exit(EXIT_FAILURE);
		}
		
		/* Write whole file measuring the latency of each access */
		while (slots_write++ < slots) {
#ifdef RANDWRITE
			position = BUFFER_SIZE * (rand() % slots);
			if (lseek(fd, position, SEEK_SET) != position) {
				perror("lseek");
				exit(EXIT_FAILURE);
			}
#endif

			gettimeofday(&start, NULL);
			bytes_write = 0;
			while (bytes_write != BUFFER_SIZE) {
				ssize_t this_write = write(fd, buf + bytes_write, BUFFER_SIZE - bytes_write);
				if (this_write == -1) {
					perror("write");
					exit(EXIT_FAILURE);
				}
				if (this_write == 0)
					break;

				bytes_write += this_write;
			}

			if (sync_file_range(fd, position, BUFFER_SIZE, SYNC_FILE_RANGE_WAIT_BEFORE | SYNC_FILE_RANGE_WRITE | SYNC_FILE_RANGE_WAIT_AFTER) == -1) {
				perror("sync_file_range");
				exit(EXIT_FAILURE);
			}

			gettimeofday(&end, NULL);
			position += bytes_write;

			/* Print write latency in ms */
			printf("%lu.%lu ", end.tv_sec, end.tv_usec/1000);
			timersub(&end, &start, &latency);
			printf("%lu\n", (latency.tv_sec * 1000) + (latency.tv_usec / 1000));
			usleep(BETWEENWRITE_PAUSE_MS * 1000);
		}
	}
}
