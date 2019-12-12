source config.sh

start_time=$(date +%s)

docker network create conjur
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
  echo "ERROR: Faield to get host api_key"
  exit 1
fi

# if it is dap then get the certificate and copy to jenkins folder
if [[ "$1" == "dap" ]]; then
  rm -rf tmp
  mkdir tmp
  cert_path="tmp/conjur-$CONJUR_ACCOUNT_NAME.pem"
  docker exec $CONJUR_NAME openssl s_client --showcerts --connect conjur-master:443 < /dev/null 2> /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $cert_path
  cp -r tmp/ jenkins/
  docker pull jenkins/jenkins
  docker build -t jenkins/conjur-jenkins:latest jenkins/
  ./setup-jenkins.sh "jenkins/conjur-jenkins:latest"
else
  ./setup-jenkins.sh "jenkins/jenkins"
fi


sleep 10
echo "import the conjur credential plugin: $CONJUR_PLUGIN_PATH"
curl -i -F file=@$CONJUR_PLUGIN_PATH http://localhost:8080/pluginManager/uploadPlugin
sleep 15

# after installing plugin copy over the team1 folder to jobs
docker cp jenkins/jobs/team1 jenkins-master:/var/jenkins_home/jobs/team1
docker exec --user root jenkins-master chown -R jenkins:jenkins /var/jenkins_home

echo "restarting jenkins"
curl http://localhost:8080/safeRestart/safeRestart --data {}

sleep 45

# delete the HOST_TEST_JENKINS credential and replace with newly generated api key
echo "Adding jenkins host api key to jenkins"
curl -X DELETE "$JENKINS_URL/job/team1/credentials/store/folder/domain/_/credential/HOST_TEST_JENKINS/config.xml"
sed "s/{{ API_KEY }}/$api_key/g" jenkins/credentials/HOST_TEST_JENKINS.xml > tmp/api_key.xml
curl -X POST -H 'content-type:application/xml' -d @tmp/api_key.xml "http://localhost:8080/job/team1/credentials/store/folder/domain/_/createCredentials"

./tests.sh

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "It took $duration seconds to stand up and test conjur and jenkins"

echo "======= ENVIRONMENT VARIABLE ======="
echo "export CONJUR_APPLIANCE_URL=https://$CONJUR_NAME"
echo "export CONJUR_AUTHN_LOGIN=$HOST_USERNAME"
echo "export CONJUR_AUTHN_API_KEY=$api_key"
echo "export CONJUR_ACCOUNT=$CONJUR_ACCOUNT_NAME"
