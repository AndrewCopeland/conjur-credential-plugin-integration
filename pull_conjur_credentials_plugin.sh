source config.sh

if [[ "$CREDENTIAL_PLUGIN_BRANCH" == "master"  ]]; then
  git clone $CREDENTIAL_PLUGIN_REPO
else
  git clone -b "$CREDENTIAL_PLUGIN_BRANCH" "$CREDENTIAL_PLUGIN_REPO"
fi

PWD=$(pwd)
cd conjur-credentials-plugin
mvn install -DskipTests
PLUGIN_PATH="$(pwd)/target/Conjur.hpi"
cd $PWD

echo "$PLUGIN_PATH"

