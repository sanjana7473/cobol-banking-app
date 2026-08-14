FROM jenkins/jenkins:lts-jdk17

# Pre-install the plugins listed in plugins.txt
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
