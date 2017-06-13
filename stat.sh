#!/bin/sh
log='/var/log/xxxxxxxxxxx'

awk '
BEGIN{
    i=0;
}
{
    request[$7]++;
}
END{
    for (item in request)
    {
        print item,request[item];
    }
}
' $log
