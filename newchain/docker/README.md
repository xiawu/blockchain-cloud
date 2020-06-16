# Build (If you are interested in going from scratch)

docker build -t newchain:latest . --network=host

# Pull
At this point in time, a Docker image dedicated to this task has been built. Users can directly pull the image as follows:

docker pull xiawuatzeuux/newchain


# Run

If you are building the image by yourself, you can try the following instruction:

 docker run -it --name newchain -d -p 8801:8801 -p 38311:38311/tcp -p 38311:38311/udp newchain:latest

If you use the image built by Xiawu, please use the following instruction:

 docker run -it --name newchain -d -p 8801:8801 -p 38311:38311/tcp -p 38311:38311/udp xiawuatzeuux/newchain:latest


# 说明
newchain_docker.sh相较于[https://release.cloud.diynova.com/newton/newchain-deploy/mainnet/newchain.sh](https://release.cloud.diynova.com/newton/newchain-deploy/mainnet/newchain.sh)的不同在于，我们将supervisor相关代码片段给删除了。

因为容器本身就是在隔离环境内运行一个独立的进程，它并不适用于像虚机那样运行一个init.d进程，所以直接运行geth就可以了。

```
冒号前边为宿主机外部端口（目录），冒号后边为宿主机内部端口（目录），如果希望在一台Server上部署多个newchain实例，不妨执行如下批量代码

docker run -it -d -p 8801:8801 -p 38311:38311/tcp -p 38311:38311/udp newchain:latest
docker run -it -d -p 8802:8801 -p 38312:38311/tcp -p 38312:38311/udp newchain:latest
docker run -it -d -p 8803:8801 -p 38313:38311/tcp -p 38313:38311/udp newchain:latest
```
