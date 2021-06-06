#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
import configparser
import os
import sys

from os.path import dirname


def set_home(package: str):
    env_file = config["GLOBAL"]["EnvFile"]
    home_dir = config[package]["Home"]
    # 删除之前存在的家目录变量
    try:
        read = open(env_file, "r")
        lines = read.readlines()
        read.close()
        out = open(env_file, "w")
        for line in lines:
            key = package + "_HOME"
            if key not in line:
                out.write(line)
        out.close()
    except Exception as e:
        pass

    # 写出新的家目录配置
    out = open(env_file, "a")
    out.write("#" + package + "_HOME\n")
    out.write("export " + package + "_HOME=" + home_dir + "\n")
    out.write("export PATH=$PATH:$" + package + "_HOME/bin")
    if os.path.exists(home_dir + "/sbin"):
        out.write(":$" + package + "_HOME/sbin")
    out.write("\n")
    out.close()


if __name__ == "__main__":
    config = configparser.ConfigParser()
    config.read(dirname(sys.argv[0]) + "/config.ini")
    try:
        if sys.argv[1] in ["java", "hadoop", "flume", "zookeeper", "hive", "kafka", "spark", "hbase"]:
            set_home(sys.argv[1].upper())
        else:
            pass
    except Exception as e:
        print(e)
