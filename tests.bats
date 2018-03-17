#!/usr/bin/env bats

IMAGE="scholzj/qpid-cpp"
VERSION="travis"

IFSBAK=$IFS
IFS=""
SERVER_PUBLIC_KEY=$(cat ./test/localhost.crt)
SERVER_PRIVATE_KEY=$(cat ./test/localhost.pem)
CLIENT_KEY_DB=$(cat ./test/crt.db)
IFS=$IFSBAK

setup() {
    # Volume container
    docker create -v /test --name testdata scholzj/circleci-centos-amqp:latest /bin/true
    docker cp ./test testdata:/
}

teardown() {
    docker stop $cont
    docker rm $cont
    # Delete volume container
    docker stop testdata
    docker rm testdata
}

tcpPort() {
    docker port $cont 5672 | cut -f 2 -d ":"
}

sslPort() {
    docker port $cont 5671 | cut -f 2 -d ":"
}

@test "No options" {
    cont=$(docker run -P --name qpidd -d $IMAGE:$VERSION)
    port=$(tcpPort)
    sleep 5 # give the image time to start
    run docker run --link qpidd:qpidd scholzj/circleci-centos-amqp:latest qpid-config -b qpidd:5672 list queue
    [ "$status" -eq "0" ]
}

@test "Option passing" {
    cont=$(docker run -P -d $IMAGE:$VERSION)
    sleep 5 # give the image time to start
    traceLines=$(docker logs $cont 2>&1 | grep trace | wc -l)
    [ "$traceLines" -eq "0" ]
    docker stop $cont
    docker rm $cont

    cont=$(docker run -P -d $IMAGE:$VERSION --trace)
    sleep 5 # give the image time to start
    traceLines=$(docker logs $cont 2>&1 | grep trace | wc -l)
    [ "$traceLines" -gt "0" ]
}

@test "Username and password" {
    cont=$(docker run -P --name qpidd -e QPIDD_ADMIN_USERNAME=jakub -e QPIDD_ADMIN_PASSWORD=big_secret -d $IMAGE:$VERSION)
    port=$(tcpPort)
    sleep 5 # give the image time to start
    run docker run --link qpidd:qpidd scholzj/circleci-centos-amqp:latest qpid-config -b qpidd:5672 list queue
    [ "$status" -ne "0" ]

    run docker run --link qpidd:qpidd scholzj/circleci-centos-amqp:latest qpid-config -b admin/admin@qpidd:5672 list queue
    [ "$status" -ne "0" ]    

    run docker run --link qpidd:qpidd scholzj/circleci-centos-amqp:latest qpid-config -b jakub/big_secret@qpidd:5672 list queue
    echo "Output: $output"
    [ "$status" -eq "0" ]
}

@test "Custom ACL rules" {
    cont=$(docker run -P --name qpidd -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_ACL_RULES="acl allow all all" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    sleep 5 # give the image time to start
    run docker run --link qpidd:qpidd scholzj/circleci-centos-amqp:latest qpid-config -b admin/123456@qpidd:5672 list queue
    echo "Output: $output"
    [ "$status" -eq "0" ]
    docker stop $cont
    docker rm $cont

    cont=$(docker run -P --name qpidd -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_ACL_RULES="acl deny-log all all" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    run docker run --link qpidd:qpidd scholzj/circleci-centos-amqp:latest qpid-config -b admin/123456@qpidd:5672 list queue
    [ "$status" -ne "0" ]
}

@test "Custom config file" {
    cont=$(docker run -P --name qpidd -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_CONFIG_OPTIONS="auth=no" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    sleep 5 # give the image time to start
    run docker run --link qpidd:qpidd scholzj/circleci-centos-amqp:latest qpid-config -b qpidd:5672 list queue
    [ "$status" -eq "0" ]
}

@test "Username and password over TCP and SSL" {
    cont=$(docker run -P --name qpidd -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_SSL_SERVER_PUBLIC_KEY="$SERVER_PUBLIC_KEY" -e QPIDD_SSL_SERVER_PRIVATE_KEY="$SERVER_PRIVATE_KEY" -d $IMAGE:$VERSION)
    port=$(tcpPort)
    sport=$(sslPort)
    sleep 5 # give the image time to start
    run docker run --link qpidd:qpidd scholzj/circleci-centos-amqp:latest qpid-config -b admin/123456@qpidd:5672 list queue
    [ "$status" -eq "0" ]

    run docker run --link qpidd:qpidd --volumes-from testdata scholzj/circleci-centos-amqp:latest openssl s_client -host qpidd -port 5671 -CAfile /test/localhost.crt -verify 100 -verify_return_error
    [ "$status" -eq "0" ]
}

@test "SSL client authentication - CAs" {
    cont=$(docker run -P --name qpidd -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_SSL_SERVER_PUBLIC_KEY="$SERVER_PUBLIC_KEY" -e QPIDD_SSL_SERVER_PRIVATE_KEY="$SERVER_PRIVATE_KEY" -e QPIDD_SSL_TRUSTED_CA="$CLIENT_KEY_DB" -d $IMAGE:$VERSION)
    sport=$(sslPort)
    sleep 5 # give the image time to start

    run docker run --link qpidd:qpidd --volumes-from testdata scholzj/circleci-centos-amqp:latest openssl s_client -host qpidd -port 5671 -CAfile /test/localhost.crt -verify 100 -verify_return_error
    [ "$status" -ne "0" ]

    run docker run --link qpidd:qpidd --volumes-from testdata scholzj/circleci-centos-amqp:latest openssl s_client -host qpidd -port 5671 -CAfile /test/localhost.crt -verify 100 -verify_return_error -cert /test/wrong_user.crt -key /test/wrong_user.pem
    [ "$status" -ne "0" ]

    run docker run --link qpidd:qpidd --volumes-from testdata scholzj/circleci-centos-amqp:latest openssl s_client -host qpidd -port 5671 -CAfile /test/localhost.crt -verify 100 -verify_return_error -cert /test/user1.crt -key /test/user1.pem
    [ "$status" -eq "0" ]
}

@test "SSL client authentication - Peers" {
    cont=$(docker run -P --name qpidd -e QPIDD_ADMIN_USERNAME=admin -e QPIDD_ADMIN_PASSWORD=123456 -e QPIDD_SSL_SERVER_PUBLIC_KEY="$SERVER_PUBLIC_KEY" -e QPIDD_SSL_SERVER_PRIVATE_KEY="$SERVER_PRIVATE_KEY" -e QPIDD_SSL_TRUSTED_PEER="$CLIENT_KEY_DB" -d $IMAGE:$VERSION)
    sport=$(sslPort)
    sleep 5 # give the image time to start

    run docker run --link qpidd:qpidd --volumes-from testdata scholzj/circleci-centos-amqp:latest openssl s_client -host qpidd -port 5671 -CAfile /test/localhost.crt -verify 100 -verify_return_error
    [ "$status" -ne "0" ]

    run docker run --link qpidd:qpidd --volumes-from testdata scholzj/circleci-centos-amqp:latest openssl s_client -host qpidd -port 5671 -CAfile /test/localhost.crt -verify 100 -verify_return_error -cert /test/wrong_user.crt -key /test/wrong_user.pem
    [ "$status" -ne "0" ]

    run docker run --link qpidd:qpidd --volumes-from testdata scholzj/circleci-centos-amqp:latest openssl s_client -host qpidd -port 5671 -CAfile /test/localhost.crt -verify 100 -verify_return_error -cert /test/user1.crt -key /test/user1.pem
    [ "$status" -eq "0" ]
}

@test "Store dir" {
    cont=$(docker run -P --name qpidd -e QPIDD_STORE_DIR=/var/lib/qpidd/my-store -d $IMAGE:$VERSION)
    sleep 5 # give the image time to start
    traceLines=$(docker logs $cont 2>&1 | grep "store-dir=/var/lib/qpidd/my-store" | wc -l)
    [ "$traceLines" -gt "0" ]
}
