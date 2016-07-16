[![Build Status](https://travis-ci.org/scholzj/docker-qpid-cpp.svg?branch=master)](https://travis-ci.org/scholzj/docker-qpid-cpp)

# docker-qpid-cpp

Docker image for Qpid C++ broker. The image is based on CentOS 7.

## Using the image

The Docker image can be configured using following envrionment variables.

- `QPIDD_HOME` defines the broker home directory, where most files will be stored. By default `/var/lib/qpidd`
- `QPIDD_SASL_DB` defines the path to the SASL databases containing users and passwors. By default `$QPIDD_HOME/etc/sasl/qpidd.sasldb`
- `QPIDD_SASL_CONFIG_DIR` defines the directory where the SASL cofngiuration file will be stored. By default `$QPIDD_HOME/etc/sasl/`
- `QPIDD_ADMIN_USERNAME` and `QPIDD_ADMIN_PASSWORD` allow to specify the username and password for the admin user which will be created. If not specified, no user will be created.
- `QPIDD_SSL_DB_DIR` defines the directory where the NSS tools certificate database will be created. By default `$QPIDD_HOME/etc/ssl`
- `QPIDD_SSL_SERVER_PUBLIC_KEY` and `QPIDD_SSL_SERVER_PRIVATE_KEY` specify the public and private keys of the broker certificate. (The keys should be stored in these variables as strings, not as a path to file). If specified, the broker will be configured with SSL
- `QPIDD_SSL_TRUSTED_CA` defines the certificates which will be accepted as trusted CA certificates
- `QPIDD_SSL_TRUSTED_PEER` defines the certificates which will be accepted as trusted peers certificates
- `QPIDD_SSL_NO_DICT` specifies that the broker should not allow username/password based connections over SSL. It will allow only SSL client authentication.
- `QPIDD_ACL_FILE` defines where the ACL file will be stored. By default `$QPIDD_HOME/etc/qpidd.acl`
- `QPIDD_ACL_RULES` can be used to specifiy the exact ACL rules which will be used. If not specified the ACL file will be either left empty, or in case `QPIDD_ADMIN_USERNAME` was specified it will allow everything for the admin user and forbid everything for everyone else
- `QPIDD_STORE_DIR` defines the broker message store directory. By default `$QPIDD_HOME/store`
- `QPIDD_PAGING_DIR` defines the broker paging directory. By default `$QPIDD_HOME/paging`
- `QPIDD_CONFIG_FILE` defines the path to the broker configuration file. By default `$QPIDD_HOME/etc/qpidd.conf`
- `QPIDD_CONFIG_OPTIONS` might contain the exact broker configuration directives which will be written into the configuration file. If not specified, the configuration file will be generated.
