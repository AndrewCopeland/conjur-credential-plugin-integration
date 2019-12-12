source config.sh

PWD=$(pwd)
docker rm -f jenkins-master
docker rm -f conjur-master
cd conjur/dev
./stop
cd $PWD

$(./cleanup-files.sh)