#!/bin/bash

#################################################################
# SCRIPT TO AUDIT UPGRADES
#################################################################

tmp_dir="/tmp/upgrade_audit"
rm -fr $tmp_dir
mkdir $tmp_dir
hostname=`hostname -f`
port='8080'
cluster_name=`curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/ |grep "cluster_name" |awk -F'"' {'print $4'}`

request_id=`curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/$cluster_name/upgrades`

comp_time_taken(){

cat $tmp_dir/status_* |grep context |awk '{$1="";$2=""; print }' |sed 's/,//g' | while read -r comp

do 
	stat=`grep -A 10 -B 10 -w "$comp" $tmp_dir/status_*|sed '1d'`
                end_time=`echo $stat |awk {'print $4'} |sed 's/,//g'`
                start_time=`echo $stat |awk {'print $8'} |sed 's/,//g'`
	if [ $end_time == "-1" ]
	then
		time_taken="0"
	else
                time_taken=`expr $end_time - $start_time`
	fi
                echo -e "\033[38m\033[42mTime taken for upgrade step\033[0m ::\033[35m ${comp} \033[0m ==> \033[34m${time_taken} (ms)\033[0m"
done

}



curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/$cluster_name/upgrades |grep "request_id" |tail -n 1 > $tmp_dir/request_id
request_id=`awk '{print $3}' $tmp_dir/request_id`
curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/$cluster_name/upgrades/$request_id  |grep "group_id"  > $tmp_dir/group_id

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#Get group_id for all task
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

for group_id in `awk '{print $3}' $tmp_dir/group_id|sed 's/,/ /g'`
do
#echo $group_id
        curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET http://$hostname:$port/api/v1/clusters/$cluster_name/upgrades/$request_id/upgrade_groups/$group_id > $tmp_dir/stage_id_$group_id

                for stage_id in `cat $tmp_dir/stage_id_$group_id |grep href|sed '1d'|awk -F "\"" '{print $4}'`
                do
                        upgrade_item=`cat $tmp_dir/stage_id_$group_id|grep $stage_id |awk -F"\"" '{print $4}'|awk -F "/" 'NF{print $NF}'`
                        #echo "++++++++++++++ $upgrade_item"
                        curl -s -u   admin:admin -H "X-Requested-By: ambari" -X GET $stage_id |grep -E -w "start_time|end_time|context|status" > $tmp_dir/status_$upgrade_item
                done
done
comp_time_taken
