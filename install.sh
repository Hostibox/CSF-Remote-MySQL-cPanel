#!/bin/bash

# Creating empty log file
touch /var/log/remote-mysql-csf.log

# Creating empty CSF configuration file
touch /etc/csf/remotemysql.allow

# Copying module script
cp ./remote-mysql-csf-add.sh /usr/local/cpanel/3rdparty/bin/remote-mysql-csf-add.sh
cp ./remote-mysql-csf-del.sh /usr/local/cpanel/3rdparty/bin/remote-mysql-csf-del.sh

# Set file permissions
chmod 755 /usr/local/cpanel/3rdparty/bin/remote-mysql-csf-add.sh
chmod 755 /usr/local/cpanel/3rdparty/bin/remote-mysql-csf-del.sh

chown root:root /usr/local/cpanel/3rdparty/bin/remote-mysql-csf-add.sh
chown root:root /usr/local/cpanel/3rdparty/bin/remote-mysql-csf-del.sh

# Installing hooks
/usr/local/cpanel/bin/manage_hooks add script /usr/local/cpanel/3rdparty/bin/remote-mysql-csf-add.sh --manual --category Cpanel --event UAPI::Mysql::add_host --stage=post --escalateprivs 1
/usr/local/cpanel/bin/manage_hooks add script /usr/local/cpanel/3rdparty/bin/remote-mysql-csf-del.sh --manual --category Cpanel --event UAPI::Mysql::delete_host --stage=post --escalateprivs 1

# Import existing Remote MySQL hosts
mysql mysql -e "select Host,User from user where Host!='localhost' group by Host;" | awk {'print "tcp|in|d=3306|s=" $1'} | sed "s/\%//g" | egrep "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -v "127.0.0.1" | sort | uniq >> /etc/csf/remotemysql.allow

# Remove any duplicate hosts
cat /etc/csf/remotemysql.allow | uniq > /tmp/remotemysql.allow
cat /tmp/remotemysql.allow > /etc/csf/remotemysql.allow
rm -f /tmp/remotemysql.allow

# Adding Remote MySQL configuration file to CSF
echo "Include /etc/csf/remotemysql.allow" >> /etc/csf/csf.allow

# Reload CSF
csf -r
