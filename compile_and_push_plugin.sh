source config.sh

PWD=$(pwd)
cd conjur-credentials-plugin
mvn install -DskipTests
PLUGIN_PATH="$(pwd)/target/Conjur.hpi"
cd $PWD

echo "import the conjur credential plugin: $PLUGIN_PATH"
sleep 2
curl -i -F file=@$PLUGIN_PATH http://localhost:8080/pluginManager/uploadPlugin
sleep 30
curl http://localhost:8080/safeRestart/safeRestart --data {}
