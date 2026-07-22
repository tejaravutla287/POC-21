pipeline {
    agent any
    environment {
        REGISTRY_USER = 'bhanutejaravutla' // Ensure this matches your user profile
        IMAGE_NAME    = 'secured-app'
        IMAGE_TAG     = "${BUILD_NUMBER}"
    }
    stages {
        stage('Artifact Package Compilation') {
            steps {
                echo 'Compiling artifact and caching dependencies to local ~/.m2 directory...'
                // This downloads all dependencies to the host cache so Trivy doesn't fetch them externally
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Trivy FS Scan') {
            steps {
                echo 'Scanning compiled project filesystem using local cache bounds...'
                // --scanners vuln skips structural secret parsing loops
                // --skip-db-update skips pulling the 100MB database again
                sh 'trivy fs . --severity HIGH,CRITICAL --scanners vuln --skip-db-update --exit-code 0'
            }
        }
        
        stage('SonarQube Quality Gate') {
            steps {
                echo 'Running Static Code Analysis...'
                sh "mvn sonar:sonar -Dsonar.host.url=http://localhost:9000 -Dsonar.login=admin -Dsonar.password=admin123"
            }
        }

        stage('Container Image Construction') {
            steps {
                echo 'Building optimized multi-stage Docker Image...'
                sh "docker build -t ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG} ."
                sh "docker tag ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY_USER}/${IMAGE_NAME}:latest"
            }
        }

        stage('Trivy Image Scan') {
            steps {
                echo 'Scanning compiled container layers...'
                sh "trivy image ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG} --severity HIGH,CRITICAL --skip-db-update --exit-code 0"
            }
        }

        stage('Push to Registry') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh "echo '${PASS}' | docker login -u '${USER}' --password-stdin"
                    sh "docker push ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${REGISTRY_USER}/${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo 'Deploying application to local K3s Cluster...'
                sh "sed -i 's|image: .*|image: ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG}|g' k8s/deployment.yaml"
                sh "sudo kubectl apply -f k8s/deployment.yaml"
                sh "sudo kubectl apply -f k8s/service.yaml"
            }
        }
    }
}
