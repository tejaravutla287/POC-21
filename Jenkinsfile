pipeline {
    agent any
    environment {
        REGISTRY_USER = 'YOUR_DOCKERHUB_USERNAME' // Change this to your username
        IMAGE_NAME    = 'secured-app'
        IMAGE_TAG     = "${BUILD_NUMBER}"
    }
    stages {
        stage('Trivy FS Scan') {
            steps {
                echo 'Scanning source code for vulnerabilities and leaked secrets...'
                sh 'trivy fs . --severity HIGH,CRITICAL --exit-code 0'
            }
        }
        
        stage('SonarQube Quality Gate') {
            steps {
                echo 'Running Static Code Analysis...'
                // Using Host native Maven execution to save internal system memory
                sh "mvn sonar:sonar -Dsonar.host.url=http://localhost:9000 -Dsonar.login=admin -Dsonar.password=admin123"
            }
        }

        stage('Build & Containerize') {
            steps {
                echo 'Building optimized multi-stage Docker Image...'
                sh "docker build -t ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG} ."
                sh "docker tag ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY_USER}/${IMAGE_NAME}:latest"
            }
        }

        stage('Trivy Image Scan') {
            steps {
                echo 'Scanning compiled container layers...'
                sh "trivy image ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG} --severity HIGH,CRITICAL --exit-code 0"
            }
        }

        stage('Push to Registry') {
            steps {
                // Ensure you configure 'docker-hub-creds' via your Jenkins UI Credentials Manager
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
