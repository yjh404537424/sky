#http://www.cnblogs.com/terryguan/p/4554207.html
ps -A --sort -rss -o comm,pmem,pcpu |uniq -c |head -15
