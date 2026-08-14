// COBOL Banking Application — CI/CD pipeline
//
// Stages: Checkout -> Build/Compile -> Unit Test -> Integration Test
//         -> Deploy Env A -> Deploy Env B -> Collect Results
//         -> Evaluate Metrics -> Publish Report
//
// Environment A is the local machine (defaults to "localhost", i.e. the Jenkins
// agent). Environment B is the Oracle Cloud Always Free VM (skip until Phase 6
// provisions it — leave ENV_B_HOST blank).
//
// Required Jenkins credentials:
//   env-b-ssh : SSH private key (with username) for Environment B
//
// Build time is captured both by Jenkins' built-in stage timers (timestamps()
// option) and by in-run timers written to results/*-timing.json.

pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        ansiColor('xterm')
    }

    parameters {
        string(name: 'ENV_A_HOST', defaultValue: 'localhost',
               description: 'Environment A (local) host. Use "localhost" to run on the Jenkins agent.')
        string(name: 'ENV_A_USER', defaultValue: '',
               description: 'SSH user for Environment A (blank if local).')
        string(name: 'ENV_B_HOST', defaultValue: '',
               description: 'Environment B (Oracle Cloud VM) host or IP. Leave blank to skip (Phase 6).')
        string(name: 'ENV_B_USER', defaultValue: 'ubuntu',
               description: 'SSH user for Environment B.')
        string(name: 'MF_HOST', defaultValue: '127.0.0.1',
               description: 'CI mainframe host used for Build/Compile and Integration Test (JES2 reader).')
        string(name: 'MF_PORT', defaultValue: '3505',
               description: 'JES2 reader port (card reader).')
        string(name: 'SYSLOG_URL', defaultValue: 'http://127.0.0.1:8038/cgi-bin/tasks/syslog',
               description: 'Hercules web-console syslog URL.')
        string(name: 'TK5_PRINTER', defaultValue: '',
               description: 'Optional: printer file path on the target (default auto-detect).')
    }

    environment {
        MF_HOST     = "${params.MF_HOST}"
        MF_PORT     = "${params.MF_PORT}"
        SYSLOG_URL  = "${params.SYSLOG_URL}"
        TK5_PRINTER = "${params.TK5_PRINTER}"
        ENV_A_HOST  = "${params.ENV_A_HOST}"
        ENV_A_USER  = "${params.ENV_A_USER}"
        ENV_B_HOST  = "${params.ENV_B_HOST}"
        ENV_B_USER  = "${params.ENV_B_USER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build / Compile') {
            steps {
                // Reset + allocate HERC01.LOAD and compile all 3 programs (IKFCBL00).
                sh 'bash ci/compile.sh'
            }
        }

        stage('Unit Test') {
            steps {
                // Data/layout integrity checks (Phase 3 will add COBOL test drivers).
                sh 'bash ci/unit-test.sh'
            }
        }

        stage('Integration Test') {
            steps {
                // Run BANKRUN and diff against golden expected output.
                sh 'bash ci/integration-test.sh'
            }
        }

        stage('Deploy Environment A') {
            steps {
                sh 'bash ci/deploy-env.sh A "${ENV_A_HOST}" "${ENV_A_USER}"'
            }
        }

        stage('Deploy Environment B') {
            when {
                expression { return params.ENV_B_HOST?.trim() }
            }
            steps {
                sshagent(['env-b-ssh']) {
                    sh 'bash ci/deploy-env.sh B "${ENV_B_HOST}" "${ENV_B_USER}"'
                }
            }
        }

        stage('Collect Results') {
            steps {
                sh 'bash ci/collect-results.sh'
            }
        }

        stage('Evaluate Metrics') {
            steps {
                sh 'python3 ci/evaluate-metrics.py'
            }
        }

        stage('Publish Report') {
            steps {
                sh 'python3 ci/generate-report.py'
                archiveArtifacts artifacts: 'results/report.md, results/report.html, results/metrics.json, results/**/report.txt',
                                 allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'results/unit-test.xml'
            archiveArtifacts artifacts: 'results/**', allowEmptyArchive: true
        }
        failure {
            echo 'Pipeline failed. See stage logs above.'
        }
    }
}
