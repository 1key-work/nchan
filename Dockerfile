# syntax = docker/dockerfile:experimental


##
## builder
##
FROM debian:buster-slim AS builder

ENV NGINX_PKG_RELEASE 1~buster

ENV MODULES_DIR /usr/local/nginx/modules
ENV DEBIAN_FRONTEND noninteractive

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && apt-get update
RUN apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates wget git
RUN apt-get install -y dpkg-dev libpcre3-dev zlib1g-dev

WORKDIR /usr/local/src
RUN git clone --depth=1 https://github.com/google/ngx_brotli.git
WORKDIR /usr/local/src/ngx_brotli
RUN git submodule update --init

WORKDIR /usr/local/src
ENV NCHAN_VERSION 1.2.7
RUN wget "https://github.com/slact/nchan/archive/v${NCHAN_VERSION}.tar.gz" -O nchan.tar.gz
RUN tar zxf nchan.tar.gz

ENV NGINX_VERSION 1.19.1

# retrieve nginx source
RUN echo "deb-src https://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list
RUN NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
  KEY_SERVER=hkp://keyserver.ubuntu.com:80; \
  apt-key adv --keyserver "$KEY_SERVER" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY"
RUN apt-get update
RUN apt-get source nginx=${NGINX_VERSION}-${NGINX_PKG_RELEASE}

# build nchan module
WORKDIR /usr/local/src/nginx-${NGINX_VERSION}
RUN ./configure --with-compat --add-dynamic-module=/usr/local/src/nchan-${NCHAN_VERSION}
RUN make -f objs/Makefile objs/ngx_nchan_module.so

RUN mkdir -p ${MODULES_DIR}
RUN mv objs/ngx_nchan_module.so ${MODULES_DIR}


WORKDIR /usr/local/src/nginx-${NGINX_VERSION}
RUN ./configure --with-compat --add-dynamic-module=/usr/local/src/ngx_brotli
RUN make modules
RUN mv objs/ngx_http_brotli_filter_module.so ${MODULES_DIR}
RUN mv objs/ngx_http_brotli_static_module.so ${MODULES_DIR}

##
## release
##
FROM nginx:1.19.1

ENV MODULES_DIR /usr/local/nginx/modules

RUN mkdir -p ${MODULES_DIR}

COPY --from=builder \
  ${MODULES_DIR}/ngx_nchan_module.so ${MODULES_DIR}
COPY --from=builder \
  ${MODULES_DIR}/ngx_http_brotli_filter_module.so ${MODULES_DIR}
COPY --from=builder \
  ${MODULES_DIR}/ngx_http_brotli_static_module.so ${MODULES_DIR}

RUN echo "$(echo -e "load_module ${MODULES_DIR}/ngx_http_brotli_static_module.so;\nload_module ${MODULES_DIR}/ngx_http_brotli_filter_module.so;\nload_module ${MODULES_DIR}/ngx_nchan_module.so;\n" | cat - /etc/nginx/nginx.conf )"> /etc/nginx/nginx.conf

#RUN mv /tmp/nginx.conf /etc/nginx/nginx.conf
#COPY ./conf.d/default.conf /etc/nginx/conf.d/
