#!/bin/bash

PROGRAM=spidey
WORKSPACE=/tmp/$PROGRAM.$(id -u)
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
    cksum=$(md5sum $WORKSPACE/test | awk '{print $1}')
    if [ $cksum != $1 ]; then
	echo "FAILURE: md5sum $cksum != $1" > $WORKSPACE/test
	return 1;
    fi
}

check_header() {
    status=$(head -n 1 $WORKSPACE/header | tr -d '\r\n')
    content=$(awk '/Content/ { print $2 }' $WORKSPACE/header | tr -d '\r\n')
    if [ "$status" != "$1" ]; then
	echo "FAILURE: $status != $1" > $WORKSPACE/test
	return 1;
    fi
    if [ "$content" != "$2" ]; then
	echo "FAILURE: content-type: $content != $2" > $WORKSPACE/test
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

check_hrefs() {
    if [ "$(sed -En 's/.*a href="([^"]+)".*/\1/p' $WORKSPACE/test | sort | paste -s -d ,)" != $1 ]; then
	echo "FAILURE: hrefs != $1" > $WORKSPACE/test
	return 1;
    fi
}

# Setup

mkdir $WORKSPACE

trap "cleanup" EXIT
trap "cleanup 1" INT TERM

# Testing

# ------------------------------------------------------------------------------

echo
cowsay -W 72 <<EOF
On another machine, please run:

    valgrind --leak-check=full ./bin/spidey -r ~pbui/pub/www -p PORT -c MODE

- Where PORT is a number between 9000 - 9999

- Where MODE is either single or forking
EOF
echo

HOST="$1"
while [ -z "$HOST" ]; do
    read -p "Server Host: " HOST
done

PORT="$2"
while [ -z "$PORT" ]; do
    read -p "Server Port: " PORT
done

echo
echo "Testing spidey server on $HOST:$PORT ..."

# ------------------------------------------------------------------------------

printf "\n %-64s ... \n" "Handle Browse Requests"

printf "     %-60s ... " "/"
HREFS="/..,/html,/images,/scripts,/song.txt,/text"
STATUS="HTTP/1.0 200 OK"
CONTENT="text/html"
curl -s -D $WORKSPACE/header $HOST:$PORT/ > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all ".. html scripts text" $WORKSPACE/test || ! check_hrefs $HREFS || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/html"
HREFS="/html/..,/html/index.html"
curl -s -D $WORKSPACE/header $HOST:$PORT/html > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all ".. index.html" $WORKSPACE/test || ! check_hrefs $HREFS || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/images"
HREFS="/images/..,/images/a.png,/images/b.jpg,/images/c.jpg,/images/d.png"
curl -s -D $WORKSPACE/header $HOST:$PORT/images > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all ".. a.png b.jpg c.jpg d.png" $WORKSPACE/test || ! check_hrefs $HREFS || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/scripts"
HREFS="/scripts/..,/scripts/cowsay.sh,/scripts/env.sh,/scripts/hello.py"
curl -s -D $WORKSPACE/header $HOST:$PORT/scripts > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all ".. cowsay.sh env.sh" $WORKSPACE/test || ! check_hrefs $HREFS || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/text"
HREFS="/text/..,/text/hackers.txt,/text/lyrics.txt,/text/pass"
curl -s -D $WORKSPACE/header $HOST:$PORT/text > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all ".. hackers.txt lyrics.txt" $WORKSPACE/test || ! check_hrefs $HREFS || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

printf "     %-60s ... " "/text/pass"
HREFS="/text/pass/..,/text/pass/fail"
curl -s -D $WORKSPACE/header $HOST:$PORT/text/pass > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all ".. fail" $WORKSPACE/test || ! check_hrefs $HREFS || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

# ------------------------------------------------------------------------------

printf "\n %-64s ... \n" "Handle File Requests"

printf "     %-60s ... " "/html/index.html"
MD5SUM=36fcc1da4afe58242350ee3940bb4220
STATUS="HTTP/1.0 200 OK"
CONTENT="text/html"
curl -s -D $WORKSPACE/header $HOST:$PORT/html/index.html > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "Spidey html thumbnail" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/images/a.png"
MD5SUM=648cb635b64492a5d78041a8094a9df0
CONTENT="image/png"
curl -s -D $WORKSPACE/header $HOST:$PORT/images/a.png > $WORKSPACE/test
if ! check_status $? 0 || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/images/b.jpg"
MD5SUM=7552baf02d08fb11a5f76677a9de6bb1
CONTENT="image/jpeg"
curl -s -D $WORKSPACE/header $HOST:$PORT/images/b.jpg > $WORKSPACE/test
if ! check_status $? 0 || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/images/c.jpg"
MD5SUM=e165e1eb8fd07260db2c9bdb963cc91d
CONTENT="image/jpeg"
curl -s -D $WORKSPACE/header $HOST:$PORT/images/c.jpg > $WORKSPACE/test
if ! check_status $? 0 || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/images/d.png"
MD5SUM=575bfc9fec29c2d867a094da9eb929dc
CONTENT="image/png"
curl -s -D $WORKSPACE/header $HOST:$PORT/images/d.png > $WORKSPACE/test
if ! check_status $? 0 || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/text/hackers.txt"
MD5SUM=c77059544e187022e19b940d0c55f408
CONTENT="text/plain"
curl -s -D $WORKSPACE/header $HOST:$PORT/text/hackers.txt > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "criminal Damn kids beauty Mentor" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/text/lyrics.txt"
MD5SUM=083de1aef4143f2ec2ef7269700a6f07
curl -s -D $WORKSPACE/header $HOST:$PORT/text/lyrics.txt > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "love me close eyes" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/text/pass/fail"
MD5SUM=7fbdff94348a88b08e989f9ac66879ae
curl -s -D $WORKSPACE/header $HOST:$PORT/text/pass/fail > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "justice" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/song.txt"
MD5SUM=d073749ecc174b560cded952656a4f57
curl -s -D $WORKSPACE/header $HOST:$PORT/song.txt > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "Right void where" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

# ------------------------------------------------------------------------------

printf "\n %-64s ... \n" "Handle CGI Requests"

printf "     %-60s ... " "/scripts/env.sh"
CONTENT="text/plain"
HEADERS="DOCUMENT_ROOT QUERY_STRING REMOTE_ADDR REMOTE_PORT REQUEST_METHOD REQUEST_URI SCRIPT_FILENAME SERVER_PORT HTTP_HOST HTTP_USER_AGENT"
curl -s -D $WORKSPACE/header $HOST:$PORT/scripts/env.sh > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "$HEADERS" $WORKSPACE/test || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/scripts/cowsay.sh"
MD5SUM=ddc37544d37e4ff1ca8c43eae6ff0f9d
CONTENT="text/html"
curl -s -D $WORKSPACE/header $HOST:$PORT/scripts/cowsay.sh > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "Cowsay surgery daemon cheese sheep" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/scripts/cowsay.sh?message=hi"
MD5SUM=4b88cc20abfb62fe435c55e98f23ff43
CONTENT="text/html"
curl -s -D $WORKSPACE/header $HOST:$PORT/scripts/cowsay.sh?message=hi > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "Cowsay surgery daemon cheese sheep" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/scripts/cowsay.sh?message=hi&template=vader"
MD5SUM=91bd83301e691e52406f9bf8722ae5fc
CONTENT="text/html"
curl -s -D $WORKSPACE/header "$HOST:$PORT/scripts/cowsay.sh?message=hi&template=vader" > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "Cowsay surgery daemon cheese sheep" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/scripts/hello.py"
MD5SUM=f42061ae140a94c559a9d21bd48b9753
CONTENT="text/html"
curl -s -D $WORKSPACE/header $HOST:$PORT/scripts/hello.py > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "form input user" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "/scripts/hello.py?user=pparker"
MD5SUM=c8b21ed36d22e523d25715b62170a783
CONTENT="text/html"
curl -s -D $WORKSPACE/header "$HOST:$PORT/scripts/hello.py?user=pparker" > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "form input user Hello" $WORKSPACE/test || ! check_md5sum $MD5SUM || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

# ------------------------------------------------------------------------------

printf "\n %-64s ... \n" "Handle Errors"

printf "     %-60s ... " "/asdf"
STATUS="HTTP/1.0 404 Not Found"
CONTENT="text/html"
curl -s -D $WORKSPACE/header $HOST:$PORT/asdf > $WORKSPACE/test
if ! check_status $? 0 || ! grep_all "404" $WORKSPACE/test || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "Bad Request"
STATUS="HTTP/1.0 400 Bad Request"
CONTENT="text/html"
nc $HOST $PORT <<<"DERP" |& tee $WORKSPACE/test $WORKSPACE/header > /dev/null
if ! check_status $? 0 || ! grep_all "400" $WORKSPACE/test || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi

sleep 1

printf "     %-60s ... " "Bad Headers"
STATUS="HTTP/1.0 400 Bad Request"
CONTENT="text/html"
printf "GET / HTTP/1.0\r\nHost\r\n" | nc $HOST $PORT |& tee $WORKSPACE/test $WORKSPACE/header > /dev/null
if ! check_status $? 0 || ! grep_all "400" $WORKSPACE/test || ! check_header "$STATUS" "$CONTENT"; then
    error "Failure"
else
    echo "Success"
fi
