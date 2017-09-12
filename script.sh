#!/bin/bash

#################################################################
# SCRIPT TO AUDIT UPGRADES
#################################################################

tmp_dir="/tmp/upgrade_audit"
rm -fr $tmp_dir
mkdir $tmp_dir
hostname=`hostname -f`
port='8080'

request_id=`curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/hdptest/upgrades`

comp_time_taken(){
components="namenode datanode secondary standby zkfc resourcemanager nodemanager history mapreduce  zookeeper"

for comp in `echo $components`
do
	stat=`grep -A10 -B 10 -i $comp $tmp_dir/status*`
	val=`echo $?`
	if [ $val == 1 ]
	then
		echo "$comp is not available in cluster" &>$tmp_dir/component_na
	else
		end_time=`echo $stat|grep end_time|cut -d':' -f2|cut -d',' -f1|sed 's/ //g'`
		#echo $end_time
		start_time=`echo $stat|grep start_time|cut -d':' -f3|cut -d',' -f1|sed 's/ //g'`
		#echo $start_time
		#echo "$comp $start_time $end_time" 
		time_taken=`expr $end_time - $start_time`
		echo "Time taken for upgrading ${comp} ==> ${time_taken}"
	fi
done
}


curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/hdptest/upgrades |grep "request_id" |tail -n 1 > $tmp_dir/request_id
request_id=`awk '{print $3}' $tmp_dir/request_id`
curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/hdptest/upgrades/$request_id  |grep "group_id"  > $tmp_dir/group_id

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#Get group_id for all task
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

for group_id in `awk '{print $3}' /tmp/group_id|sed 's/,/ /g'`
do
#echo $group_id
	curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/hdptest/upgrades/$request_id/upgrade_groups/$group_id > $tmp_dir/stage_id_$group_id

		for stage_id in `cat $tmp_dir/stage_id_$group_id |grep href|sed '1d'|awk -F "\"" '{print $4}'`
		do
			upgrade_item=`cat $tmp_dir/stage_id_$group_id|grep $stage_id |awk -F"\"" '{print $4}'|awk -F "/" 'NF{print $NF}'`
			#echo "++++++++++++++ $upgrade_item"
			curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET $stage_id |grep -E -w "start_time|end_time|text|status" > $tmp_dir/status_$upgrade_item
		done
done
comp_time_taken
