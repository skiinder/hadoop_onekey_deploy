#!/usr/bin/env bash
mysql_to_hdfs_init.sh all 2020-06-14
hdfs_to_ods_log.sh 2020-06-14
hdfs_to_ods_db_init.sh all 2020-06-14
ods_to_dim_db_init.sh all 2020-06-14
ods_to_dwd_db_init.sh all 2020-06-14
ods_to_dwd_log.sh all 2020-06-14
dwd_to_dws_init.sh all 2020-06-14
dws_to_dwt_init.sh all 2020-06-14
dwt_to_ads.sh all 2020-06-14
hdfs_to_mysql.sh all 2020-06-14
