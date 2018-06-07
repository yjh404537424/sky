#!/bin/bash
redis_comm=/usr/bin/redis-cli

redis_ser01="10.9.102.19 -p 6380"
redis_ser02="10.9.102.19 -p 6381"
redis_ser03="10.9.102.19 -p 6382"

$redis_comm -c -h $redis_ser01 keys $1 | xargs -i redis-cli -h $redis_ser01 del {}
$redis_comm -c -h $redis_ser02 keys $1 | xargs -i redis-cli -h $redis_ser02 del {}
$redis_comm -c -h $redis_ser03 keys $1 | xargs -i redis-cli -h $redis_ser03 del {}
