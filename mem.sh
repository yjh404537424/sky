ps -A --sort -rss -o comm,pmem,pcpu |uniq -c |head -15
