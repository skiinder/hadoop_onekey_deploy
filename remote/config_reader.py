#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
import configparser
import sys
from os.path import dirname

# 接受两个参数输入, 分别是Section和Key, 返回对应配置的值
if __name__ == "__main__":
    config = configparser.ConfigParser()
    config.read(dirname(sys.argv[0]) + "/config.ini")
    try:
        print(config[sys.argv[1]][sys.argv[2]])
    except KeyError:
        exit(1)
