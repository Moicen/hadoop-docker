# Creates pseudo distributed hadoop 2.7.1
#
# ./build.sh

FROM alpine
MAINTAINER l.weinan@gmail.com

USER root

# install dev tools
#RUN apk add curl which tar sudo openssh-server openssh-clients rsync
RUN apk add curl which tar sudo rsync openssh zip unzip bash openjdk8 wget 
# http://www.iops.cc/make-splunk-docker-w
RUN apk add --update procps


# passwordless ssh
# https://www.ssh.com/ssh/host-key
RUN ssh-keygen -A
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys


# download native support
RUN mkdir -p /tmp/native
COPY hadoop-native-64-2.7.1.tgz /tmp/native
RUN cd /tmp/native && tar zxvf hadoop-native-64-2.7.1.tgz

# hadoop
COPY hadoop-2.7.1.tar.gz /usr/local
RUN cd /usr/local && ls && tar zxvf hadoop-2.7.1.tar.gz
RUN cd /usr/local && ln -s ./hadoop-2.7.1 hadoop

# learn code
COPY hadoop-book /root/hadoop-book
COPY run_example.sh /root

ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop

ENV JAVA_HOME /usr/lib/jvm/default-jvm

ENV USER root

RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/lib/jvm/default-jvm\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
#RUN . $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

RUN mkdir $HADOOP_PREFIX/input
RUN cp $HADOOP_PREFIX/etc/hadoop/*.xml $HADOOP_PREFIX/input

# pseudo distributed
ADD core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml
ADD hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml

ADD mapred-site.xml $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
ADD yarn-site.xml $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

RUN $HADOOP_PREFIX/bin/hdfs namenode -format

# fixing the libhadoop.so like a boss
RUN rm -rf /usr/local/hadoop/lib/native
RUN mv /tmp/native /usr/local/hadoop/lib

ADD ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

# # installing supervisord
# RUN yum install -y python-setuptools
# RUN easy_install pip
# RUN curl https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -o - | python
# RUN pip install supervisor
#
# ADD supervisord.conf /etc/supervisord.conf

ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

# workingaround docker.io build error
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh
RUN chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh

# fix the 254 error code
#RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
#RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

# https://stackoverflow.com/questions/14612371/how-do-i-run-multiple-background-commands-in-bash-in-a-single-line
RUN /usr/sbin/sshd -D & $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && \
 $HADOOP_PREFIX/sbin/start-dfs.sh && \
 $HADOOP_PREFIX/bin/hdfs dfsadmin -safemode leave && \
 $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/root
RUN /usr/sbin/sshd -D & $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && \
 $HADOOP_PREFIX/sbin/start-dfs.sh && \
 $HADOOP_PREFIX/bin/hdfs dfsadmin -safemode leave && \ 
 $HADOOP_PREFIX/bin/hdfs dfs -put $HADOOP_PREFIX/etc/hadoop/ input
 
# https://github.com/gliderlabs/docker-alpine/issues/397
RUN apk add busybox-extras

CMD ["/etc/bootstrap.sh", "-d"]

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 10020 19888
#Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
#Other ports
EXPOSE 49707 2122
