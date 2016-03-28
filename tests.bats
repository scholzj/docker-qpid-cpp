#!/usr/bin/env bats

IMAGE="scholzj/qpid-cpp"
VERSION="travis"

teardown() {
    sudo docker stop $cont
    sudo docker rm $cont
}

tcpPort() {
    sudo docker port $cont 5672 | cut -f 2 -d ":"
}

sslPort() {
    sudo docker port $cont 5671 | cut -f 2 -d ":"
}

@test "No options" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    port=$(tcpPort)
    echo "port=$port"
    run qpid-config -b 127.0.0.1:$port list queue
    [ "$status" -eq "0" ]
}

@test "Option passing" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    traceLines=$(sudo docker logs $cont 2>&1 | grep trace | wc -l)
    sleep 5 # give the image time to start
    [ "$traceLines" -eq "0" ]
    sudo docker stop $cont
    sudo docker rm $cont

    cont=$(sudo docker run -P -d $IMAGE:$VERSION --trace)
    sleep 5 # give the image time to start
    traceLines=$(sudo docker logs $cont 2>&1 | grep trace | wc -l)
    [ "$traceLines" -gt "0" ]
}

@test "Username and password" {
    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=jakub -e QPIDD_ADMIN_PASSWORD=big_secret -d $IMAGE:$VERSION)
    port=$(tcpPort)
    run qpid-config -b localhost:$port list queue >> /dev/null
    [ "$status" -ne "0" ]

    run qpid-config -b admin/admin@localhost:$port list queue >> /dev/null
    [ "$status" -ne "0" ]    

    run qpid-config -b jakub/big_secret@localhost:$port list queue
    [ "$status" -eq "0" ]
}

@test "ACL rules" {
    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_ACL_RULES="acl allow all all" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    run qpid-config -b admin/123456@localhost:$port list queue >> /dev/null
    [ "$status" -eq "0" ]
    sudo docker stop $cont
    sudo docker rm $cont

    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_ACL_RULES="acl deny-log all all" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    run qpid-config -b admin/123456@localhost:$port list queue >> /dev/null
    [ "$status" -ne "0" ]
}


