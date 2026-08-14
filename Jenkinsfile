// COBOL Banking Application — CI/CD pipeline (TK5 via FTP)
//
// Stages:
//   Checkout -> Build/Compile -> Unit Test -> Integration Test
//            -> Benchmark Env A (RUN_COUNT x) -> Benchmark Env B (RUN_COUNT x)
//            -> Compare & Evaluate -> Publish Report
//
// Submission uses FTP (default): each JCL file is uploaded to the FTP server
// watched by tk5-ftp-watcher.sh, which auto-submits it to the JES2 reader.
//
// Environment A is the local machine ("localhost" = the Jenkins agent).
// Environment B is the Oracle Cloud Always Free VM (skipped until Phase 6
// provisions it — leave ENV_B_HOST blank).
//
// Required Jenkins credentials:
//   env-b-ssh : SSH private key (with username) for Environment B
//
// Build time is captured by Jenkins' built-in stage timers (timestamps() option)
// and by per-run timers written to results/env-*/benchmark.json.

pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 180, unit: 'MINUTES')
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
               description: 'CI mainframe host for Build/Compile and Integration Test.')
        string(name: 'MF_PORT', defaultValue: '3505',
               description: 'JES2 reader port (used in socket mode).')
        string(name: 'SYSLOG_URL', defaultValue: 'http://127.0.0.1:8038/cgi-bin/tasks/syslog',
               description: 'Hercules web-console syslog URL.')
        string(name: 'TK5_PRINTER', defaultValue: '',
               description: 'Optional: printer file path on the target (default auto-detect).')
        string(name: 'MF_SUBMIT', defaultValue: 'ftp',
               description: 'Submission transport: ftp (default) or socket.')
        string(name: 'FTP_HOST', defaultValue: '127.0.0.1', description: 'FTP server host.')
        string(name: 'FTP_PORT', defaultValue: '2121', description: 'FTP server port.')
        string(name: 'FTP_USER', defaultValue: 'herc01', description: 'FTP user.')
        string(name: 'FTP_PASS', defaultValue: 'cul8tr', description: 'FTP password.')
        string(name: 'RUN_COUNT', defaultValue: '14',
               description: 'Number of full compile+run repetitions per environment.')
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
        MF_SUBMIT   = "${params.MF_SUBMIT}"
        FTP_HOST    = "${params.FTP_HOST}"
        FTP_PORT    = "${params.FTP_PORT}"
        FTP_USER    = "${params.FTP_USER}"
        FTP_PASS    = "${params.FTP_PASS}"
        RUN_COUNT   = "${params.RUN_COUNT}"
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Build / Compile') {
            steps { sh 'bash ci/compile.sh' }
        }

        stage('Unit Test') {
            steps { sh 'bash ci/unit-test.sh' }
        }

        stage('Integration Test') {
            steps { sh 'bash ci/integration-test.sh' }
        }

        stage('Benchmark Env A (${RUN_COUNT}x)') {
            steps { sh 'bash ci/run-benchmark.sh A "${ENV_A_HOST}" "${ENV_A_USER}"' }
        }

        stage('Benchmark Env B (${RUN_COUNT}x)') {
            when { expression { return params.ENV_B_HOST?.trim() } }
            steps {
                sshagent(['env-b-ssh']) {
                    sh 'bash ci/run-benchmark.sh B "${ENV_B_HOST}" "${ENV_B_USER}"'
                }
            }
        }

        stage('Compare & Evaluate') {
            steps {
                sh 'python3 ci/compare-benchmarks.py'
                sh 'python3 ci/evaluate-metrics.py'
                sh 'python3 ci/generate-report.py'
            }
        }

        stage('Publish Report') {
            steps {
                archiveArtifacts artifacts: 'results/**', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'results/unit-test.xml'
            archiveArtifacts artifacts: 'results/**', allowEmptyArchive: true
        }
        failure { echo 'Pipeline failed. See stage logs above.' }
    }
}
