#!/bin/bash
redis_list=("10.9.102.149:6380" "10.9.102.149:6380" "10.9.102.149:6381")
#password="redispassword=="

for info in ${redis_list[@]}
do
    echo "开始执行:$info"  
    ip=`echo $info | cut -d : -f 1`
    port=`echo $info | cut -d : -f 2`
    redis-cli -h $ip -p $port -c keys $1 |xargs -t -n1 redis-cli -h $ip -p $port -c del
done
echo "完成"
