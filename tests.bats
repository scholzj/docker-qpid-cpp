#!/usr/bin/env bats

IMAGE="scholzj/qpid-cpp"
VERSION="travis"

IFSBAK=$IFS
IFS=""
SERVER_PUBLIC_KEY=$(cat ./test/localhost.crt)
SERVER_PRIVATE_KEY=$(cat ./test/localhost.pem)
CLIENT_KEY_DB=$(cat ./test/crt.db)
IFS=$IFSBAK

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
    sleep 5 # give the image time to start
    run qpid-config -b localhost:$port list queue
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
    sleep 5 # give the image time to start
    run qpid-config -b localhost:$port list queue
    [ "$status" -ne "0" ]

    run qpid-config -b admin/admin@localhost:$port list queue
    [ "$status" -ne "0" ]    

    run qpid-config -b jakub/big_secret@localhost:$port list queue
    echo "Output: $output"
    [ "$status" -eq "0" ]
}

@test "Custom ACL rules" {
    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_ACL_RULES="acl allow all all" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    sleep 5 # give the image time to start
    run qpid-config -b admin/123456@localhost:$port list queue
    echo "Output: $output"
    [ "$status" -eq "0" ]
    sudo docker stop $cont
    sudo docker rm $cont

    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_ACL_RULES="acl deny-log all all" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    run qpid-config -b admin/123456@localhost:$port list queue
    [ "$status" -ne "0" ]
}

@test "Custom config file" {
    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_CONFIG_OPTIONS="auth=no" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    sleep 5 # give the image time to start
    run qpid-config -b localhost:$port list queue
    [ "$status" -eq "0" ]
}

@test "Username and password over TCP and SSL" {
    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_SSL_SERVER_PUBLIC_KEY="$SERVER_PUBLIC_KEY" -e QPIDD_SSL_SERVER_PRIVATE_KEY="$SERVER_PRIVATE_KEY" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    sport=$(sslPort)
    sleep 5 # give the image time to start
    run qpid-config -b admin/123456@localhost:$port list queue
    [ "$status" -eq "0" ]

    run openssl s_client -host localhost -port $sport -CAfile test/localhost.crt -verify 100 -verify_return_error
    [ "$status" -eq "0" ]
}

@test "SSL client authentication - CAs" {
    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_SSL_SERVER_PUBLIC_KEY="$SERVER_PUBLIC_KEY" -e QPIDD_SSL_SERVER_PRIVATE_KEY="$SERVER_PRIVATE_KEY" -e QPIDD_SSL_TRUSTED_CA="$CLIENT_KEY_DB" -d $IMAGE:$VERSION)
    sport=$(sslPort)
    sleep 5 # give the image time to start

    run openssl s_client -host localhost -port $sport -CAfile test/localhost.crt -verify 100 -verify_return_error
    [ "$status" -ne "0" ]

    run openssl s_client -host localhost -port $sport -CAfile test/localhost.crt -verify 100 -verify_return_error -cert test/wrong_user.crt -key test/wrong_user.pem
    [ "$status" -ne "0" ]

    run openssl s_client -host localhost -port $sport -CAfile test/localhost.crt -verify 100 -verify_return_error -cert test/user1.crt -key test/user1.pem
    [ "$status" -eq "0" ]
}

@test "SSL client authentication - Peerss" {
    cont=$(sudo docker run -P -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_SSL_SERVER_PUBLIC_KEY="$SERVER_PUBLIC_KEY" -e QPIDD_SSL_SERVER_PRIVATE_KEY="$SERVER_PRIVATE_KEY" -e QPIDD_SSL_TRUSTED_PEER="$CLIENT_KEY_DB" -d $IMAGE:$VERSION)
    sport=$(sslPort)
    sleep 5 # give the image time to start

    run openssl s_client -host localhost -port $sport -CAfile test/localhost.crt -verify 100 -verify_return_error
    [ "$status" -ne "0" ]

    run openssl s_client -host localhost -port $sport -CAfile test/localhost.crt -verify 100 -verify_return_error -cert test/wrong_user.crt -key test/wrong_user.pem
    [ "$status" -ne "0" ]

    run openssl s_client -host localhost -port $sport -CAfile test/localhost.crt -verify 100 -verify_return_error -cert test/user1.crt -key test/user1.pem
    [ "$status" -eq "0" ]
}

