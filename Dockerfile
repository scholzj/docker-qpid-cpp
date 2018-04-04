FROM		centos:centos7
LABEL           maintainer="Jakub Scholz <www@scholzj.com>"

# Add qpidd group / user
RUN groupadd -r qpidd && useradd -r -d /var/lib/qpidd -m -g qpidd qpidd

# Install all dependencies
RUN curl -o /etc/yum.repos.d/qpid-proton-stable.repo http://repo.effectivemessaging.com/qpid-proton-stable.repo \
        && curl -o /etc/yum.repos.d/qpid-cpp-stable.repo http://repo.effectivemessaging.com/qpid-cpp-stable.repo \
        && curl -o /etc/yum.repos.d/qpid-python-stable.repo http://repo.effectivemessaging.com/qpid-python-stable.repo \
        && yum -y install epel-release \
        && yum -y --setopt=tsflag=nodocs install openssl cyrus-sasl cyrus-sasl-md5 cyrus-sasl-plain qpid-cpp-server qpid-cpp-server-linearstore qpid-cpp-server-xml qpid-tools qpid-proton-c \
        && yum clean all

ENV QPIDD_VERSION 1.38.0

RUN chown -R qpidd:qpidd /var/lib/qpidd
VOLUME /var/lib/qpidd

# Add entrypoint
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

USER qpidd:qpidd

# Expose port and run
EXPOSE 5671 5672
CMD ["qpidd"]
