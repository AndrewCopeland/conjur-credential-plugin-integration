source config.sh
source utils.sh

start_time=$(date +%s)

./cleanup.sh || true
docker network create conjur || true

api_key=""
if [[ "$1" == "dap" ]]; then
  ./setup-dap.sh | tee output
elif [[ "$1" == "oss" ]]; then
  ./setup-conjur-oss.sh | tee output
else
  echo "Invalid argument '$1' must be 'dap' or 'oss'"
  exit 1
fi

api_key=$(cat output | tail -n 1 | awk -F "API_KEY: " '{print $2}')
rm output

if [[ "$api_key" == "" ]]; then
  echo "ERROR: Failed to get host api_key"
  exit 1
fi

# if it is dap then get the certificate and copy to jenkins folder (self-signed certificate)
if [[ "$1" == "dap" ]]; then
  rm -rf tmp
  mkdir tmp
  cert_path="tmp/conjur-$CONJUR_ACCOUNT_NAME.pem"
  docker exec $CONJUR_NAME openssl s_client --showcerts --connect conjur-master:443 < /dev/null 2> /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $cert_path
  cat "$cert_path"
  cp $cert_path jenkins/
  docker pull jenkins/jenkins:2.206
  docker build -t jenkins/conjur-jenkins:latest jenkins/
  ./setup-jenkins.sh "jenkins/conjur-jenkins:latest"
else
  ./setup-jenkins.sh "jenkins/jenkins:2.206"
fi

sleep 10

# configure conjur authn-jenkins authenticator
if [ $MOUNT_AUTHN_JENKINS = true ]; then
  header=$(conjur_authenticate)
  echo "loading authn-jenkins policies"
  config_authn_jenkins="./$(repo_name $GIT_AUTHN_JENKINS)/tests/config.yml"
  job_authn_jenkins="./$(repo_name $GIT_AUTHN_JENKINS)/tests/job.yml"

  append_policy "root" "$config_authn_jenkins"
  append_policy "root" "$job_authn_jenkins"

  set_variable "conjur/authn-jenkins/prod/jenkinsURL" "http://jenkins-master:8080"
  set_variable "conjur/authn-jenkins/prod/jenkinsUsername" "conjur"
  set_variable "conjur/authn-jenkins/prod/jenkinsPassword" "cyberark1"
  set_variable "team1/secret" "$TEAM_SECRET"

  echo "setting jenkins certificate in conjur"
  jenkins_public_key=$(curl -sSL -D - http://localhost:8080 -o /dev/null | grep "X-Instance-Identity" | awk -F 'X-Instance-Identity: ' '{print $2}')
  echo "jenkins public key: $jenkins_public_key"
  set_variable "conjur/authn-jenkins/prod/jenkinsCertificate" "$jenkins_public_key"
fi

if [ $BUILD_HPI_FROM_REPO = true ]; then
  output=$(./pull_conjur_credentials_plugin.sh)
  export CONJUR_PLUGIN_PATH=$(echo "$output" | tail -n 1)
fi

echo "import the conjur credential plugin: $CONJUR_PLUGIN_PATH"
curl -i -F file=@$CONJUR_PLUGIN_PATH http://localhost:8080/pluginManager/uploadPlugin
echo "import the git plugin: $GIT_PLUGIN"
curl -X POST -d "<jenkins><install plugin=\"$GIT_PLUGIN\" /></jenkins>" --header 'Content-Type: text/xml' http://localhost:8080/pluginManager/installNecessaryPlugins

sleep 45

# after installing plugin copy over the needed content (configuration, credential and jobs)
docker cp jenkins/jobs jenkins-master:/var/jenkins_home
docker cp jenkins/org.conjur.jenkins.configuration.GlobalConjurConfiguration.xml jenkins-master:/var/jenkins_home/org.conjur.jenkins.configuration.GlobalConjurConfiguration.xml
docker cp jenkins/credentials.xml jenkins-master:/var/jenkins_home/credentials.xml
docker exec --user root jenkins-master chown -R jenkins:jenkins /var/jenkins_home

sleep 15

echo "restarting jenkins"
curl http://localhost:8080/safeRestart/safeRestart --data {}

sleep 45

# delete the HOST_TEST_JENKINS credential and replace with newly generated api key
echo "Adding jenkins host api key to jenkins for folder"
curl -X DELETE "$JENKINS_URL/job/team1/credentials/store/folder/domain/_/credential/HOST_TEST_JENKINS/config.xml"
sed "s/{{ API_KEY }}/$api_key/g" jenkins/credentials/HOST_TEST_JENKINS.xml > tmp/api_key.xml
curl -X POST -H 'content-type:application/xml' -d @tmp/api_key.xml "http://localhost:8080/job/team1/credentials/store/folder/domain/_/createCredentials"

echo "Adding jenkins host api key to jenkins for global"
curl -X DELETE "$JENKINS_URL/credentials/store/system/domain/_/credential/HOST_TEST_JENKINS_GLOBAL/config.xml"
sed "s/{{ API_KEY }}/$api_key/g" jenkins/credentials/HOST_TEST_JENKINS_GLOBAL.xml > tmp/api_key.xml
curl -X POST -H 'content-type:application/xml' -d @tmp/api_key.xml "$JENKINS_URL/credentials/store/system/domain/_/createCredentials"


./tests.sh

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "It took $duration seconds to stand up and test conjur and jenkins"

echo "======= ENVIRONMENT VARIABLE ======="
echo "export CONJUR_APPLIANCE_URL=https://$CONJUR_NAME"
echo "export CONJUR_AUTHN_LOGIN=$HOST_USERNAME"
echo "export CONJUR_AUTHN_API_KEY=$api_key"
echo "export CONJUR_ACCOUNT=$CONJUR_ACCOUNT_NAME"
