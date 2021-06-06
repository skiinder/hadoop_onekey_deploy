#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
import configparser
import os
import sys
import tarfile
import io

import requests
from os.path import dirname


# 将指定tar包解压并重命名
def extract_tar(source: str, target: str):
    target_dir = dirname(target)
    os.makedirs(name=target_dir, mode=0o755, exist_ok=True)
    stream = requests.get(source, stream=True).raw if source.startswith("http") else open(source, mode="rb")
    tarfile_open = tarfile.open(fileobj=io.BytesIO(stream.read()), mode="r|gz")
    member = tarfile_open.next()
    original_name = member.name.split("/")[0] if member else None
    while member:
        tarfile_open.extract(member, target_dir)
        member = tarfile_open.next()
    if original_name and (target_dir + "/" + original_name) != target:
        os.renames(target_dir + "/" + original_name, target)
    tarfile_open.close()


if __name__ == "__main__":
    global_config = configparser.ConfigParser()
    global_config.read(dirname(sys.argv[0]) + "/config.ini")
    try:
        if len(sys.argv) == 2:
            package_config = global_config[sys.argv[1].upper()]
            home_dir = package_config["Home"]
            archive = package_config["Archive"]
            extract_tar(archive if archive.startswith("/") or archive.startswith("http") else global_config["GLOBAL"][
                                                                                                  "DefaultSource"] + "/" + archive
                        , home_dir)
        else:
            extract_tar(sys.argv[1], sys.argv[2])
    except Exception as e:
        print(e)
