# 扫描当前目录下所以git project的文件
# 进行git pull
# location: git/
for dirlist in $(ls -d */)
do
    echo $dirlist
    cd $dirlist
    git pull
    cd ..
done
