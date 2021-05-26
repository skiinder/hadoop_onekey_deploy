#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
import configparser
import os
import re
import shutil
import socket
import sys
import xml.dom.minidom
import xml.etree.cElementTree as etree
import xml.sax

from os.path import dirname


class Properties:
    def __init__(self, file):
        self.__pros = {}
        self.__source = file
        try:
            pro_file = open(self.__source, "r")
            for line in pro_file:
                if line.find("=") > 0 and not re.match("^ *#", line):
                    s = line.replace("\n", "").split("=")
                    self.__pros[s[0]] = s[1]
            pro_file.close()
        except Exception:
            pass

    def clear(self):
        self.__pros.clear()

    def __getitem__(self, item):
        return self.__pros.get(item)

    def __setitem__(self, key, value):
        self.__pros[key] = value

    def save(self):
        try:
            pro_file = open(self.__source, "w")
            for key, value in self.__pros.items():
                pro_file.writelines(key + "=" + value + "\n")
            pro_file.close()
        except Exception as e:
            print(e)


class Configuration:
    def __init__(self, file: str):
        self.__source = file
        self.__pros = {}
        try:
            doc = etree.parse(file).getroot()
            for item in doc.findall("property"):
                self.__pros[item.find("name").text] = item.find("value").text
        except Exception:
            pass

    def clear(self):
        self.__pros.clear()

    def __getitem__(self, item):
        return self.__pros.get(item)

    def __setitem__(self, key, value):
        self.__pros[key] = value

    def save(self):
        doc = xml.dom.minidom.Document()
        pi = doc.createProcessingInstruction(
            "xml-stylesheet", 'type="text/xsl" href="configuration.xsl"')
        root = doc.createElement("configuration")
        doc.appendChild(root)
        for name, value in self.__pros.items():
            props = doc.createElement("property")
            name_node = doc.createElement("name")
            name_node.appendChild(doc.createTextNode(name))
            value_node = doc.createElement("value")
            value_node.appendChild(doc.createTextNode(value))
            props.appendChild(name_node)
            props.appendChild(value_node)
            root.appendChild(props)
        doc.insertBefore(pi, root)
        output = open(self.__source, "w")
        doc.writexml(output, indent="", addindent="    ", newl="\n", encoding="utf-8")
        output.close()


def config_null():
    pass


def config_hadoop():
    config = global_config["HADOOP"]
    # 修改core-site.xml
    core_site = Configuration(config["Home"] + "/etc/hadoop/core-site.xml")
    core_site.clear()
    core_site["hadoop.tmp.dir"] = config["Data"]
    core_site["hadoop.http.staticuser.user"] = username
    core_site["hadoop.http." + username + ".hosts"] = "*"
    core_site["hadoop.http." + username + ".groups"] = "*"
    core_site["hadoop.http." + username + ".users"] = "*"
    name_nodes = config["NameNode"].split(",")
    zk_hosts = global_config["ZOOKEEPER"]["Host"].split(",")
    if not len(name_nodes) > 1:
        core_site["fs.defaultFS"] = "hdfs://" + name_nodes[0] + ":8020"
    else:
        name_service = config["NameService"]
        core_site["fs.defaultFS"] = "hdfs://" + name_service
        core_site["ha.zookeeper.quorum"] = ":2181,".join(zk_hosts) + ":2181"
    core_site.save()

    # 修改hdfs-site.xml
    hdfs_site = Configuration(config["Home"] + "/etc/hadoop/hdfs-site.xml")
    hdfs_site.clear()
    if not len(name_nodes) > 1:
        hdfs_site["dfs.namenode.secondary.http-address"] = config["SecondaryNameNode"] + ":9868"
        hdfs_site["dfs.namenode.http-address"] = name_nodes[0] + ":9870"
    else:
        name_service = config["NameService"]
        hdfs_site["dfs.namenode.name.dir"] = "file://${hadoop.tmp.dir}/name"
        hdfs_site["dfs.datanode.data.dir"] = "file://${hadoop.tmp.dir}/data"
        hdfs_site["dfs.journalnode.edits.dir"] = "${hadoop.tmp.dir}/jn"
        hdfs_site["dfs.nameservices"] = name_service
        aliases = list(map(lambda x: "nn" + str(x), range(1, len(name_nodes) + 1)))
        hdfs_site["dfs.ha.namenodes." + name_service] = ",".join(aliases)
        for name_node, alias in zip(name_nodes, aliases):
            hdfs_site["dfs.namenode.rpc-address." + name_service + "." + alias] = name_node + ":8020"
            hdfs_site["dfs.namenode.http-address." + name_service + "." + alias] = name_node + ":9870"
        hdfs_site["dfs.namenode.shared.edits.dir"] = "qjournal://" + ":8485;".join(
            config["JournalNode"].split(",")) + ":8485/" + name_service
        hdfs_site["dfs.client.failover.proxy.provider.mycluster"] = ("org.apache.hadoop.hdfs.server.namenode.ha."
                                                                     "ConfiguredFailoverProxyProvider")
        hdfs_site["dfs.ha.fencing.methods"] = "sshfence"
        keyfile = list(filter(lambda x: "id" in x and "pub" not in x, os.listdir("/home/" + username + "/.ssh/")))[0]
        hdfs_site["dfs.ha.fencing.ssh.private-key-files"] = "/home/" + username + "/.ssh/" + keyfile
        hdfs_site["dfs.ha.automatic-failover.enabled"] = "true"
    hdfs_site.save()

    # 修改mapred-site.xml
    mapred_site = Configuration(config["Home"] + "/etc/hadoop/mapred-site.xml")
    mapred_site.clear()
    mapred_site["mapreduce.framework.name"] = "yarn"
    mapred_site["mapreduce.jobhistory.address"] = config["JobHistoryServer"] + ":10020"
    mapred_site["mapreduce.jobhistory.webapp.address"] = config["JobHistoryServer"] + ":19888"
    mapred_site.save()

    # 修改yarn-site.xml
    yarn_site = Configuration(config["Home"] + "/etc/hadoop/yarn-site.xml")
    yarn_site.clear()
    yarn_site["yarn.nodemanager.aux-services"] = "mapreduce_shuffle"
    yarn_site["yarn.nodemanager.pmem-check-enabled"] = "true"
    yarn_site["yarn.nodemanager.vmem-check-enabled"] = "false"
    yarn_site["yarn.scheduler.minimum-allocation-mb"] = "1024"
    yarn_site["yarn.scheduler.maximum-allocation-mb"] = "8192"
    yarn_site["yarn.log-aggregation-enable"] = "true"
    yarn_site["yarn.log.server.url"] = mapred_site["mapreduce.jobhistory.webapp.address"] + "/jobhistory/logs"
    yarn_site["yarn.log-aggregation.retain-seconds"] = "604800"
    yarn_site["yarn.nodemanager.env-whitelist"] = ("JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,"
                                                   "CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME")
    resource_managers = config["ResourceManager"].split(",")
    if not len(resource_managers) > 1:
        yarn_site["yarn.resourcemanager.hostname"] = resource_managers[0]
    else:
        yarn_site["yarn.resourcemanager.ha.enabled"] = "true"
        yarn_site["yarn.resourcemanager.cluster-id"] = config["YarnService"]
        aliases = list(map(lambda x: "rm" + str(x), range(1, len(resource_managers) + 1)))
        yarn_site["yarn.resourcemanager.ha.rm-ids"] = ",".join(aliases)
        for resource_manager, alias in zip(resource_managers, aliases):
            yarn_site["yarn.resourcemanager.hostname." + alias] = resource_manager
            yarn_site["yarn.resourcemanager.webapp.address." + alias] = resource_manager + ":8088"
            yarn_site["yarn.resourcemanager.address." + alias] = resource_manager + ":8032"
            yarn_site["yarn.resourcemanager.scheduler.address." + alias] = resource_manager + ":8030"
            yarn_site["yarn.resourcemanager.resource-tracker.address." + alias] = resource_manager + ":8031"
        yarn_site["yarn.resourcemanager.zk-address"] = ":2181,".join(zk_hosts) + ":2181"
        yarn_site["yarn.resourcemanager.recovery.enabled"] = "true"
        yarn_site["yarn.resourcemanager.store.class"] = ("org.apache.hadoop.yarn.server.resourcemanager."
                                                         "recovery.ZKRMStateStore")
    yarn_site.save()

    workers = open(config["Home"] + "/etc/hadoop/workers", mode="w")
    for worker in config["Workers"].split(","):
        workers.write(worker + "\n")
    workers.close()


def config_zookeeper():
    config = global_config["ZOOKEEPER"]
    hosts = config["Host"].split(",")
    ids = dict(zip(hosts, range(0, len(hosts))))
    hostname = socket.gethostname()

    data_dir = config["Data"]
    os.mkdir(data_dir)
    myid = open(data_dir + "/myid", "w")

    myid.write(str(ids[hostname]))
    myid.close()

    zoo_config = Properties(config["Home"] + "/conf/zoo.cfg")
    zoo_config.clear()
    zoo_config["tickTime"] = "2000"
    zoo_config["initLimit"] = "5"
    zoo_config["syncLimit"] = "5"
    zoo_config["clientPort"] = "2181"
    zoo_config["dataDir"] = data_dir
    for host in hosts:
        zoo_config["server." + str(ids[host])] = host + ":2888:3888"
    zoo_config.save()


def config_hive():
    config = global_config["HIVE"]
    home_dir = config["Home"]
    os.renames(home_dir + "/lib/log4j-slf4j-impl-2.10.0.jar", home_dir + "/lib/log4j-slf4j-impl-2.10.0.jar.bak")
    shutil.copy(global_config["GLOBAL"]["DefaultSource"] + "/" + global_config["MYSQL"]["Connector"], home_dir + "/lib")
    hive_site = Configuration(home_dir + "/conf/hive-site.xml")
    hive_site.clear()
    hive_site["javax.jdo.option.ConnectionURL"] = "jdbc:mysql://" + global_config["MYSQL"]["Host"] + ":3306/" \
                                                  + config["MetaDB"] + "?useSSL=false"
    hive_site["javax.jdo.option.ConnectionDriverName"] = "com.mysql.jdbc.Driver"
    hive_site["javax.jdo.option.ConnectionUserName"] = config["MySQLUser"]
    hive_site["javax.jdo.option.ConnectionPassword"] = config["MySQLPassword"]
    hive_site["hive.metastore.warehouse.dir"] = "/user/hive/warehouse"
    hive_site["hive.metastore.schema.verification"] = "false"
    hive_site["hive.server2.thrift.bind.host"] = socket.gethostname()
    hive_site["hive.metastore.event.db.notification.api.auth"] = "false"
    hive_site["hive.server2.active.passive.ha.enable"] = "true"
    hive_site["hive.server2.support.dynamic.service.discovery"] = "true"
    hive_site["hive.server2.zookeeper.namespace"] = "hiveserver2"
    hive_site["hive.zookeeper.client.port"] = "2181"
    hive_site["hive.zookeeper.quorum"] = ":2181,".join(global_config["ZOOKEEPER"]["Host"].split(",")) + ":2181"

    hive_site["hive.exec.dynamic.partition.mode"] = "nonstrict"
    hive_site.save()


def config_kafka():
    config = global_config["KAFKA"]
    kafka_config = Properties(config["Home"] + "/config/server.properties")
    hosts = config["Host"].split(",")
    ids = dict(zip(hosts, range(0, len(hosts))))
    hostname = socket.gethostname()
    kafka_config["broker.id"] = str(ids[hostname])
    kafka_config["log.dirs"] = config["Data"]
    kafka_config["zookeeper.connect"] = ":2181,".join(global_config["ZOOKEEPER"]["Host"].split(",")) + ":2181/kafka"
    kafka_config.save()


def config_spark():
    hadoop_core = Configuration(global_config["HADOOP"]["Home"] + "/etc/hadoop/core-site.xml")

    hive_config = Configuration(global_config["HIVE"]["Home"] + "/conf/hive-site.xml")
    hive_config["spark.yarn.jars"] = hadoop_core["fs.defaultFS"] + "/spark/jars/*"
    hive_config["hive.execution.engine"] = "spark"
    hive_config["hive.spark.client.connect.timeout"] = "10000ms"
    hive_config.save()

    hive_spark_config = Properties(global_config["HIVE"]["Home"] + "/conf/spark-defaults.conf")
    hive_spark_config.clear()
    hive_spark_config["spark.master"] = "yarn"
    hive_spark_config["spark.eventLog.enabled"] = "true"
    hive_spark_config["spark.eventLog.dir"] = hadoop_core["fs.defaultFS"] + "/spark/history"
    hive_spark_config["spark.executor.memory"] = "4g"
    hive_spark_config["spark.memory.offHeap.enabled"] = "true"
    hive_spark_config["spark.memory.offHeap.size"] = "2g"
    hive_spark_config.save()

    config = global_config["SPARK"]
    home_dir = config["Home"]
    spark_config = Properties(home_dir + "/conf/spark-defaults.conf")
    spark_config.clear()
    spark_config["spark.master"] = "yarn"
    spark_config["spark.eventLog.enabled"] = "true"
    spark_config["spark.eventLog.dir"] = hadoop_core["fs.defaultFS"] + "/spark/history"
    spark_config["spark.yarn.historyServer.address"] = config["HistoryServer"] + ":18080"
    spark_config["spark.sql.adaptive.enabled"] = "true"
    spark_config["spark.sql.adaptive.coalescePartitions.enabled"] = "true"
    spark_config["spark.sql.hive.convertMetastoreParquet"] = "false"
    spark_config["spark.sql.parquet.writeLegacyFormat"] = "true"
    spark_config["spark.hadoop.fs.hdfs.impl.disable.cache"] = "true"
    spark_config["spark.sql.storeAssignmentPolicy"] = "LEGACY"
    spark_config["spark.executor.memory"] = "4g"
    spark_config["spark.memory.offHeap.enabled"] = "true"
    spark_config["spark.memory.offHeap.size"] = "2g"
    spark_config.save()

    try:
        shutil.copy(global_config["HIVE"]["Home"] + "/conf/hive-site.xml", home_dir + "/conf")
        shutil.copy(global_config["GLOBAL"]["DefaultSource"] + "/" + global_config["MYSQL"]["Connector"],
                    home_dir + "/jars")
    except Exception:
        pass

    template = open(home_dir + "/conf/spark-env.sh.template", mode="r")
    spark_env = open(home_dir + "/conf/spark-env.sh", mode="w")
    for line in template.readlines():
        spark_env.write(line)
        if "YARN_CONF_DIR" in line:
            spark_env.write("YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop\n")
    template.close()
    spark_env.close()


def config_hbase():
    pass


if __name__ == "__main__":
    global_config = configparser.ConfigParser()
    global_config.read(dirname(sys.argv[0]) + "/config.ini")
    username = global_config["GLOBAL"]["Username"]
    configuration = {
        "java": config_null,
        "hadoop": config_hadoop,
        "zookeeper": config_zookeeper,
        "hive": config_hive,
        "flume": config_null,
        "sqoop": config_null,
        "kafka": config_kafka,
        "spark": config_spark,
        "hbase": config_hbase,
    }

    try:
        configuration[sys.argv[1]]()
    except Exception as e:
        print(e)
