#!/bin/bash
cd "$(dirname $0)" || exit 1
rm -rf shucang.tar.gz
tar -zcf shucang.tar.gz shucang
cp -f shucang.tar.gz /opt/software
