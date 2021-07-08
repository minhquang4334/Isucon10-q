repo=git@github.com:minhquang4334/Isucon10-q.git # 自身のISUCONレポジトリ
repo_path=/home/isucon/isuumo
benchmark=${repo_path}/bench
echo 'running deploy to this server'
cd ${repo_path}
git pull origin master
cd ${benchmark}
./bench
