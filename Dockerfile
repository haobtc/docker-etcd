# Dockerfile for ETCD

FROM phusion/baseimage:0.9.19
MAINTAINER HyperWang <hyperwangee@gmail.com>

# use aliyun source
ADD sources-aliyun.com.list /etc/apt/sources.list

RUN apt-get update
RUN apt-get install -y wget

WORKDIR /root/

RUN wget https://github.com/coreos/etcd/releases/download/v3.0.8/etcd-v3.0.8-linux-amd64.tar.gz
RUN tar zxf etcd-v3.0.8-linux-amd64.tar.gz \
  && cd etcd-v3.0.8-linux-amd64 \
  && chmod +x etcd etcdctl \
  && cp etcd etcdctl /usr/local/bin

RUN mkdir -p /opt/etcd/{data,cert}
