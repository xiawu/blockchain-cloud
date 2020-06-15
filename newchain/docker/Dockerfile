FROM ubuntu:16.04

WORKDIR /newchain
RUN apt update
RUN apt-get -y install libdigest-sha-perl curl

ENV SUDO_USER=root

EXPOSE 8801
EXPOSE 38311/tcp
EXPOSE 38311/udp

ADD newchain_docker.sh .
RUN bash newchain_docker.sh

ENTRYPOINT ["/data/newchain/mainnet/bin/geth", "--config","/data/newchain/mainnet/conf/node.toml"]