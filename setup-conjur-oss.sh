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

docker cp ./policy.yml dev_client_1:/policy.yml
api_key=$(docker exec dev_client_1 conjur policy load root policy.yml | jq .. | tail -n 2 | head -n 1 | sed 's/"//g')
echo "API_KEY: $api_key"


