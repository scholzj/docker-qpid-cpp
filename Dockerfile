FROM		centos:centos7
MAINTAINER 	JAkub Scholz "www@scholzj.com"

# Add qpidd group / user
RUN groupadd -r qpidd && useradd -r -d /var/lib/qpidd -m -g qpidd qpidd

# Install all dependencies
RUN curl -o /etc/yum.repos.d/qpid-proton-testing.repo http://repo.effectivemessaging.com/qpid-proton-testing.repo \
        && curl -o /etc/yum.repos.d/qpid-cpp-testing.repo http://repo.effectivemessaging.com/qpid-cpp-testing.repo \
        && curl -o /etc/yum.repos.d/qpid-python-testing.repo http://repo.effectivemessaging.com/qpid-python-testing.repo \
        && yum -y install epel-release \
        && yum -y --setopt=tsflag=nodocs install openssl cyrus-sasl cyrus-sasl-md5 cyrus-sasl-plain qpid-cpp-server qpid-cpp-server-linearstore qpid-cpp-server-xml qpid-tools qpid-proton-c \
        && yum clean all

ENV QPIDD_VERSION 1.35.0-BETA

VOLUME /var/lib/qpidd

# Add entrypoint
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

USER qpidd:qpidd

# Expose port and run
EXPOSE 5671 5672
CMD ["qpidd"]
