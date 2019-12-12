source config.sh

git clone "$CONJUR_GIT_REPO"
cd conjur/dev
# this will remove interactive mode
cat start | tail -r | sed -e '1,6d' | tail -r > start-tmp
chmod +x start-tmp
./start-tmp --authn-jenkins
cd ../..

# populate the values required for the jenkins authenticator
docker exec dev_client_1 conjur variable values add "conjur/authn-jenkins/prod/jenkinsURL" $JENKINS_URL
docker exec dev_client_1 conjur variable values add "conjur/authn-jenkins/prod/jenkinsUsername" $JENKINS_USERNAME
docker exec dev_client_1 conjur variable values add "conjur/authn-jenkins/prod/jenkinsPassword" $JENKINS_PASSWORD

# get the jenkins identity public key
# jenkins_cert=$(curl -s -I $JENKINS_URL  | grep -Fi X-Instance-Identity | awk -F "X-Instance-Identity: " '{print $2}')
# if [[ "$jenkins_cert" == "" ]]; then
#   echo "Error: Failed to fetch jenkins identity"
#   exit 1
# fi
# docker exec dev_client_1 conjur variable values add "conjur/authn-jenkins/prod/jenkinsCertificate" $jenkins_cert
docker cp ./policy.yml dev_client_1:/policy.yml
api_key=$(docker exec dev_client_1 conjur policy load root policy.yml | jq .. | tail -n 2 | head -n 1 | sed 's/"//g')
echo "API_KEY: $api_key"


