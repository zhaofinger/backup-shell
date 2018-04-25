#!/usr/bin/env bash

# 备份 mysql
# 支持备份到本地以及google drive
# @Author: zhaofinger

###################################### config ######################################
# 本地备份目录
LOCAL_BAK_DIR="/root/backups/data/"
# 本地临时备份目录
TEMP_BAK_DIR="/root/backups/temp/"
# 备份日志
BAK_LOG_FILE="/root/backups/backup.log"
# mysql root 密码
MYSQL_ROOT_PWD=""
# 需要备份的数据库名称
MYSQL_DATABASE_NAME[0]="database1"
# MYSQL_DATABASE_NAME[1]="database2"
# MYSQL_DATABASE_NAME[2]="database3"


###################################### constans ######################################
# Date & Time
DAY=$(date +%d)
MONTH=$(date +%m)
YEAR=$(date +%C%y)

BACKUP_DATE=$(date +%Y%m%d%H%M%S)
# 打包名称
TARFILE_NAME="${LOCAL_BAK_DIR}""$(hostname)"_"${BACKUP_DATE}".tar.gz
# sql 备份名称
SQL_FILE_NAME="${TEMP_BAK_DIR}mysql_${BACKUP_DATE}.sql"

###################################### functions ######################################
# 备份 mysql
mysql_backup() {
    if [ -z ${MYSQL_ROOT_PWD} ]; then
        echo "Error: Please config mysql password!"
    else
        echo "MySQL dump start"
        mysql -u root -p"${MYSQL_ROOT_PWD}" 2>/dev/null <<EOF
        exit
EOF
        # 密码不对
        if [ $? -ne 0 ]; then
            echo "MySQL root password is wrong!"
            exit 1
        fi

        # 开始备份
        for db in ${MYSQL_DATABASE_NAME[*]}
          do
              unset DBFILE
              DBFILE="${TEMP_BAK_DIR}${db}_${BACKUP_DATE}.sql"
              mysqldump -u root -p"${MYSQL_ROOT_PWD}" ${db} > "${DBFILE}" 2>/dev/null
              if [ $? -ne 0 ]; then
                  log "MySQL database name [${db}] backup failed!"
                  exit 1
              fi
              echo "MySQL database name ${db} dump file name: ${DBFILE}"
          done

        echo "MySQL dump completed!"
    fi
}

# 上传备份到 google drive
# 在 linux 上使用 gdrive，详情请见 https://github.com/prasmussen/gdrive
# 使用示例
# 64位: wget -O /usr/bin/gdrive http://dl.lamp.sh/files/gdrive-linux-x64 && chmod +x /usr/bin/gdrive
# 32位: wget -O /usr/bin/gdrive http://dl.lamp.sh/files/gdrive-linux-386 && chmod +x /usr/bin/gdrive
gdrive_upload() {
    if [ "$(command -v "gdrive")" ]; then
        echo "Google drive backup start!"
        gdrive upload --no-progress ${TARFILE_NAME} >> ${BAK_LOG_FILE}
        if [ $? -ne 0 ]; then
            echo "Error: Google drive backup failed!"
            exit 1
        fi
        echo "Google drive backup complete!"
    fi
}


###################################### main ######################################
# 判断是否 root 用户，否则退出
if [[ $EUID -ne 0 ]]; then
  echo "Error: Please switch to root user!"
  exit 1
fi

# 检测建立文件夹
if [ ! -d "${LOCAL_BAK_DIR}" ]; then
    mkdir -p ${LOCAL_BAK_DIR}
fi
if [ ! -d "${TEMP_BAK_DIR}" ]; then
    mkdir -p ${TEMP_BAK_DIR}
fi

# 部分命令存在检测
CMDS=( openssl mysql mysqldump pwd tar )
for CMD in "${CMDS[@]}"; do
    if [ ! "$(command -v "$CMD")" ]; then
        echo "$CMD is not installed!"
        exit 1
    fi
done

# mysql 备份
mysql_backup

# 打包
echo "Tar backup file start!"
cd ${TEMP_BAK_DIR}
tar -zcvf ${TARFILE_NAME} *.sql
if [ $? -gt 1 ]; then
    echo "Tar backup file failed"
    exit 1
fi
echo "Tar backup file completed!"

# google drive 上传
gdrive_upload

# 删除临时
echo "Delete temp file start!"
rm -f ${TEMP_BAK_DIR}/*
echo "Delete temp file complete!"