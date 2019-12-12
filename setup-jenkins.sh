echo "download & install jenkins"
docker run -d --env JAVA_OPTS=-Djenkins.install.runSetupWizard=false -p 8080:8080 --name jenkins-master --network conjur $1