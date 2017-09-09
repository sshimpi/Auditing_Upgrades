#!/bin/bash

#################################################################
# SCRIPT TO AUDIT UPGRADES
#################################################################

rm -fr /tmp/upgrade_audit
mkdir /tmp/upgrade_audit
hostname=`hostname -f`
port='8080'

request_id=`curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/hdptest/upgrades`


curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/hdptest/upgrades |grep "request_id" |tail -n 1 > /tmp/upgrade_audit/request_id
request_id=`awk '{print $3}' /tmp/upgrade_audit/request_id`
curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/hdptest/upgrades/$request_id  |grep "group_id"  > /tmp/upgrade_audit/group_id

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#Get group_id for all task
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

for group_id in `awk '{print $3}' /tmp/group_id|sed 's/,/ /g'`
do
#echo $group_id
	curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/hdptest/upgrades/$request_id/upgrade_groups/$group_id > /tmp/upgrade_audit/stage_id_$group_id

		for stage_id in `cat /tmp/upgrade_audit/stage_id_$group_id |grep href|sed '1d'|awk -F "\"" '{print $4}'`
		do
			upgrade_item=`cat /tmp/upgrade_audit/stage_id_$group_id|grep $stage_id |awk -F"\"" '{print $4}'|awk -F "/" 'NF{print $NF}'`
			#echo "++++++++++++++ $upgrade_item"
			curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET $stage_id |grep -E -w "start_time|end_time|text|status" > /tmp/upgrade_audit/status_$upgrade_item
		done
done

