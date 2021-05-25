#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
import configparser
import sys
from os.path import dirname

if __name__ == "__main__":
    config = configparser.ConfigParser()
    config.read(dirname(sys.argv[0]) + "/config.ini")
    print(config[sys.argv[1]][sys.argv[2]])
