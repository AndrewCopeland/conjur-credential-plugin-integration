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


function get_recent_build_number {
  folder=$1
  job_name=$2
  number=$(curl -s http://localhost:8080/job/$folder/job/$job_name/api/xml?xpath=/*/lastStableBuild/number | awk -F ">" '{print $2}' | awk -F "<" '{print $1}')
  echo "$number"
}

function run_job_in_folder {
  folder=$1
  job_name=$2
  curl -s -X POST http://localhost:8080/job/$folder/job/$job_name/build
  sleep 1
  echo $(get_recent_build_number "$folder" "$job_name")
}

function get_job_response_in_folder {
  folder=$1
  job_name=$2
  build_number=1
  if [[ "$3" != "" ]]; then
    build_number="$3"
  fi

  building=$(curl -s http://127.0.0.1:8080/job/$folder/job/$job_name/$build_number/api/json?pretty=true | jq .building 2>/dev/null)
  while [ "$building" != "false" ]; do
    building=$(curl -s http://127.0.0.1:8080/job/team1/job/freestyle-secret/$build_number/api/json?pretty=true | jq .building 2>/dev/null)
    sleep 1
    echo "waiting for job $folder/$job_name #$build_number to finish building"
  done

  consoleText=$(curl -s http://127.0.0.1:8080/job/$folder/job/$job_name/$build_number/consoleText)
  echo "$consoleText"
}

function start_test {
  folder=$1
  job_name=$2
  build_number=$(run_job_in_folder "$folder" "$job_name")
  echo "$build_number"
}

function validate_test {
  folder=$1
  job_name=$2
  build_number=$3
  expected_password=$(echo "$4" | base64)

  echo "Validating test - $folder/$job_name #$build_number - expected secret '$expected_password'"
  console=$(get_job_response_in_folder "$folder" "$job_name" "$build_number")
  default_password=$(echo "$console" | grep "$expected_password")
  if [[ "$default_password" == "" ]]; then
    echo "$console"
    echo "FAILED: Recieved invalid password from jenkins"
    exit 1
  fi
  echo "PASSED"
}


# run the tests
folder="team1"
id_freestyle_secret=$(start_test "$folder" "freestyle-secret")
id_freestyle_secret_username=$(start_test "$folder" "freestyle-secret-username")

validate_test "$folder" "freestyle-secret" "$id_freestyle_secret" "$GIT_ACCESS_TOKEN"
validate_test "$folder" "freestyle-secret-username" "$id_freestyle_secret_username" "$GIT_ACCESS_TOKEN"

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "It took $duration seconds to stand up and test conjur and jenkins"

echo "======= ENVIRONMENT VARIABLE ======="
echo "export CONJUR_APPLIANCE_URL=https://$CONJUR_NAME"
echo "export CONJUR_AUTHN_LOGIN=$HOST_USERNAME"
echo "export CONJUR_AUTHN_API_KEY=$api_key"
echo "export CONJUR_ACCOUNT=$CONJUR_ACCOUNT_NAME"
