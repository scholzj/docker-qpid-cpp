#!/usr/bin/env bats

SUDO="sudo "
IMAGE="scholzj/qpid-cpp"
VERSION="0.34"

teardown() {
    sudo docker stop $cont
    sudo docker rm $cont
}

tcpPort() {
    $SUDO docker port $cont 5672 | cut -f 2 -d ":"
}

sslPort() {
    $SUDO docker port $cont 5671 | cut -f 2 -d ":"
}

@test "No options" {
    cont=$($SUDO docker run -P -d $IMAGE:$VERSION)
    port=$(tcpPort)
    run qpid-config -b localhost:$port list queue
    [ "$status" -eq "0" ]
}

@test "Option passing" {
    cont=$($SUDO docker run -P -d $IMAGE:$VERSION)
    traceLines=$($SUDO docker logs $cont 2>&1 | grep trace | wc -l)
    sleep 5 # give the image time to start
    [ "$traceLines" -eq "0" ]
    $SUDO docker stop $cont
    $SUDO docker rm $cont

    cont=$($SUDO docker run -P -d $IMAGE:$VERSION --trace)
    sleep 5 # give the image time to start
    traceLines=$($SUDO docker logs $cont 2>&1 | grep trace | wc -l)
    [ "$traceLines" -gt "0" ]
}

@test "Username and password" {
    cont=$($SUDO docker run -P -e QPIDD_ADMIN_USERNAME=jakub -e QPIDD_ADMIN_PASSWORD=big_secret -d $IMAGE:$VERSION)
    port=$(tcpPort)
    run qpid-config -b localhost:$port list queue >> /dev/null
    [ "$status" -ne "0" ]

    run qpid-config -b admin/admin@localhost:$port list queue >> /dev/null
    [ "$status" -ne "0" ]    

    run qpid-config -b jakub/big_secret@localhost:$port list queue
    [ "$status" -eq "0" ]
}


