FROM		centos:centos7
LABEL           maintainer="Jakub Scholz <www@scholzj.com>"

# Add qpidd group / user
RUN groupadd -r qpidd && useradd -r -d /var/lib/qpidd -m -g qpidd qpidd

# Install all dependencies
RUN curl -o /etc/yum.repos.d/qpid-proton-devel.repo http://repo.effectivemessaging.com/qpid-proton-devel.repo \
        && curl -o /etc/yum.repos.d/qpid-cpp-devel.repo http://repo.effectivemessaging.com/qpid-cpp-devel.repo \
        && curl -o /etc/yum.repos.d/qpid-python-devel.repo http://repo.effectivemessaging.com/qpid-python-devel.repo \
        && yum -y install epel-release \
        && yum -y --setopt=tsflag=nodocs --exclude=python2-qpid\* install openssl cyrus-sasl cyrus-sasl-md5 cyrus-sasl-plain qpid-cpp-server qpid-cpp-server-linearstore qpid-cpp-server-xml qpid-tools qpid-proton-c \
        && yum clean all

ENV QPIDD_VERSION DEVEL

RUN chown -R qpidd:qpidd /var/lib/qpidd
VOLUME /var/lib/qpidd

# Add entrypoint
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

USER qpidd:qpidd

# Expose port and run
EXPOSE 5671 5672
CMD ["qpidd"]
