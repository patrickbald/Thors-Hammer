#!/bin/bash

PROGRAM=bin/thor.py
WORKSPACE=/tmp/$(basename $PROGRAM).$(id -u)
FAILURES=0

# Functions

error() {
    echo "$@"
    [ -r $WORKSPACE/test ] && (echo; cat $WORKSPACE/test; echo)
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    STATUS=${1:-$FAILURES}
    rm -fr $WORKSPACE
    exit $STATUS
}

check_status() {
    if [ $1 -ne $2 ]; then
	echo "FAILURE: exit status $1 != $2" > $WORKSPACE/test
	return 1;
    fi

    return 0;
}

check_md5sum() {
    cksum=$(grep -E -v '^(Hammer|TOTAL)' $WORKSPACE/test | sed -E '/^\s*$/d' | md5sum | awk '{print $1}')
    if [ $cksum != $1 ]; then
	echo "FAILURE: md5sum $cksum != $1" > $WORKSPACE/test
	return 1;
    fi
}

grep_all() {
    for pattern in $1; do
    	if ! grep -q -E "$pattern" $2; then
    	    echo "FAILURE: Missing '$pattern' in '$2'" > $WORKSPACE/test
    	    return 1;
    	fi
    done
    return 0;
}

grep_count() {
    if [ $(grep -i -c $1 $WORKSPACE/test) -ne $2 ]; then
	echo "FAILURE: $1 count != $2" > $WORKSPACE/test
	return 1;
    fi
    return 0;
}

# Setup

mkdir $WORKSPACE

trap "cleanup" EXIT
trap "cleanup 1" INT TERM

# Testing

echo "Testing $PROGRAM..."

# ------------------------------------------------------------------------------

printf " %-64s ... " "Functions"
if ! grep_all "ProcessPoolExecutor requests.get map time.time" $PROGRAM; then
    error "Failure"
else
    echo "Success"
fi

# ------------------------------------------------------------------------------

printf "\n %-64s\n" "Usage"

printf "     %-60s ... " "no arguments"
./$PROGRAM &> $WORKSPACE/test
if ! check_status $? 1 || ! grep_all "Usage" $WORKSPACE/test; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "bad arguments"
./$PROGRAM -b -a -d &> $WORKSPACE/test
if ! check_status $? 1 || ! grep_all "Usage" $WORKSPACE/test; then
    error "Failure"
else
    echo "Success"
fi

# ------------------------------------------------------------------------------

PATTERNS="Hammer Throw Elapsed Time TOTAL AVERAGE"

printf "\n %-64s\n" "Single Hammer"

DOMAIN=https://example.com
MD5SUM=c5953ba10795984694b107c66e922d51
printf "     %-60s ... " "$DOMAIN"
./$PROGRAM $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "$PATTERNS" $WORKSPACE/test; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-v)"
./$PROGRAM -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM; then
    error "Failure"
else
    echo "Success"
fi

DOMAIN=https://yld.me
MD5SUM=7e198de49c3d9da2572573bbd115a15b
printf "     %-60s ... " "$DOMAIN"
./$PROGRAM $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "$PATTERNS" $WORKSPACE/test; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-v)"
./$PROGRAM -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM; then
    error "Failure"
else
    echo "Success"
fi

DOMAIN=https://yld.me/izE?raw=1
MD5SUM=1877fcda6f85fa183220fdb47ecdbb9d
printf "     %-60s ... " "$DOMAIN"
./$PROGRAM $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "$PATTERNS" $WORKSPACE/test; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-v)"
./$PROGRAM -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM; then
    error "Failure"
else
    echo "Success"
fi

# ------------------------------------------------------------------------------

printf "\n %-64s\n" "Single Hammer, Multiple Throws"

DOMAIN=https://example.com
MD5SUM=0d994deecb09db39fcc67c597e1ed920
printf "     %-60s ... " "$DOMAIN (-t 4)"
./$PROGRAM -t 4 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0     || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 5 || ! grep_count Throw 4; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-t 4 -v)"
./$PROGRAM -t 4 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 5 || ! grep_count Throw 4; then
    error "Failure"
else
    echo "Success"
fi

DOMAIN=https://yld.me
MD5SUM=fcd87a5d4bc539b052fe86fdaf769b59
printf "     %-60s ... " "$DOMAIN (-t 4)"
./$PROGRAM -t 4 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 5 || ! grep_count Throw 4; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-t 4 -v)"
./$PROGRAM -t 4 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 5 || ! grep_count Throw 4; then
    error "Failure"
else
    echo "Success"
fi

DOMAIN=https://yld.me/izE?raw=1
MD5SUM=a44c9b1df78e3656398db9ba92548a56
printf "     %-60s ... " "$DOMAIN (-t 4)"
./$PROGRAM -t 4 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 5 || ! grep_count Throw 4; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-t 4 -v)"
./$PROGRAM -t 4 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 5 || ! grep_count Throw 4; then
    error "Failure"
else
    echo "Success"
fi

# ------------------------------------------------------------------------------

printf "\n %-64s\n" "Multiple Hammers"

DOMAIN=https://example.com
MD5SUM=354446ae72c1a63f18abf3ca9ddffb70
printf "     %-60s ... " "$DOMAIN (-h 2)"
./$PROGRAM -h 2 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0     || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 4 || ! grep_count Throw 2; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-h 2 -v)"
./$PROGRAM -h 2 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 4 || ! grep_count Throw 2; then
    error "Failure"
else
    echo "Success"
fi

DOMAIN=https://yld.me
MD5SUM=285a6a2a8365ebae8681967d0b7b9083
printf "     %-60s ... " "$DOMAIN (-h 2)"
./$PROGRAM -h 2 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 4 || ! grep_count Throw 2; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-h 2 -v)"
./$PROGRAM -h 2 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 4 || ! grep_count Throw 2; then
    error "Failure"
else
    echo "Success"
fi

DOMAIN=https://yld.me/izE?raw=1
MD5SUM=9df2453cf04874e6ca1124f8e49f2051
printf "     %-60s ... " "$DOMAIN (-h 2)"
./$PROGRAM -h 2 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 4 || ! grep_count Throw 2; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-p 2 -v)"
./$PROGRAM -h 2 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0   || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 4 || ! grep_count Throw 2; then
    error "Failure"
else
    echo "Success"
fi

# ------------------------------------------------------------------------------

printf "\n %-64s\n" "Multiple Hammers, Multiple Throws"

DOMAIN=https://example.com
MD5SUM=7043520023714e026f42e5dc97997770
printf "     %-60s ... " "$DOMAIN (-h 2 -t 4)"
./$PROGRAM -h 2 -t 4 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0    || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 10 || ! grep_count Throw 8; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-h 2 -t 4 -v)"
./$PROGRAM -h 2 -t 4 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0    || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 10 || ! grep_count Throw 8; then
    error "Failure"
else
    echo "Success"
fi

DOMAIN=https://yld.me
MD5SUM=6aeb58b41d0bb41abedbe7f6649f39d9
printf "     %-60s ... " "$DOMAIN (-h 2 -t 4)"
./$PROGRAM -h 2 -t 4 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0    || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 10 || ! grep_count Throw 8; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-h 2 -t 4 -v)"
./$PROGRAM -h 2 -t 4 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0    || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 10 || ! grep_count Throw 8; then
    error "Failure"
else
    echo "Success"
fi

DOMAIN=https://yld.me/izE?raw=1
MD5SUM=ce4d6bbaca157f968e6e57aa084e6ec1
printf "     %-60s ... " "$DOMAIN (-h 2 -t 4)"
./$PROGRAM -h 2 -t 4 $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0    || ! grep_all "$PATTERNS" $WORKSPACE/test || \
   ! grep_count Hammer 10 || ! grep_count Throw 8; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "$DOMAIN (-h 2 -t 4 -v)"
./$PROGRAM -h 2 -t 4 -v $DOMAIN &> $WORKSPACE/test
if ! check_status $? 0    || ! grep_all "$PATTERNS" $WORKSPACE/test || ! check_md5sum $MD5SUM || \
   ! grep_count Hammer 10 || ! grep_count Throw 8; then
    error "Failure"
else
    echo "Success"
fi
