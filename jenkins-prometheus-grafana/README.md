Gist to support https://youtu.be/3H9eNIf9KZs

# Documentation

* https://plugins.jenkins.io/prometheus/
* https://plugins.jenkins.io/cloudbees-disk-usage-simple/
* https://grafana.com/grafana/dashboards

# Commands

* `docker run -d -p 9090:9090 -v /home/vagrant/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus`

# prometheus.yml

```
global:
  scrape_interval:     15s
  evaluation_interval: 15s
  scrape_timeout:      10s

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
  - job_name: 'jenkins'
    metrics_path: /prometheus/
    static_configs:
    - targets: ['192.168.32.13:8080']
```

# sample Jenkinsfile

```
pipeline {
  agent any
  triggers { 
    cron('* * * * *')
  }
  stages {
    stage('Hello') {
      steps {
        echo 'Hello World - team-a - test'
        sleep 3
      }
    }
  }
}
```
