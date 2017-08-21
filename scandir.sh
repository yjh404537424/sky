#location git/
for dirlist in $(ls -d */)
do
    echo $dirlist
    cd $dirlist
    git pull
    cd ..
done
