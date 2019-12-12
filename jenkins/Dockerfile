FROM jenkins/jenkins
ENV JAVA_HOME /usr/local/openjdk-8
ENV JENKINS_HOME /var/jenkins_home

COPY conjur-conjur.pem $JAVA_HOME/jre/lib/security/
# COPY master.key $JENKINS_HOME/secrets/master.key
# COPY hudson.util.Secret $JENKINS_HOME/secrets/hudson.util.Secret
# COPY jobs $JENKINS_HOME/jobs

USER root
RUN $JAVA_HOME/bin/keytool -import -trustcacerts -alias conjur -keystore $JAVA_HOME/jre/lib/security/cacerts -storepass changeit -noprompt -file $JAVA_HOME/jre/lib/security/conjur-conjur.pem
RUN chown -R jenkins:jenkins $JENKINS_HOME
USER jenkins
