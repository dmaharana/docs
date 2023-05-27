### How to download Jenkins plugins with dependencies using CLI

#### Reference: https://github.com/jenkinsci/plugin-installation-manager-tool.git

#### This command downloads the plugins specified in the yaml file to a download folder 

`java -jar jenkins-plugin-manager-2.12.11.jar  --war ../jenkins.war --plugin-file jenkins-plugins.yaml -d ./plugins`

- [Download the Jenkins plugin manager jar from](https://github.com/jenkinsci/plugin-installation-manager-tool/releases/latest)
- [Download Jenkins war file](https://get.jenkins.io/war-stable/2.387.3/jenkins.war)
- [Specify the plugins list in a file](./jenkins-plugins.yaml)
