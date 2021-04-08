#!/usr/bin/env bash

set -ex
DIR=$(cd "$(dirname "$0")"; pwd)
cd $DIR
docker build . -t 1key/nchan     
docker push 1key/nchan
