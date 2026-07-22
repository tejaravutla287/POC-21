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

        stage('Upload to Nexus Repository') {
            steps {
                echo 'Publishing built JAR file to local Nexus Repository engine...'
                // Appends a local deployment block to the pom.xml on the fly and triggers upload
                sh '''
                cat << 'EOF' >> pom.xml
                    <distributionManagement>
                        <repository>
                            <id>nexus-releases</id>
                            <url>http://localhost:8081/repository/maven-releases/</url>
                        </repository>
                    </distributionManagement>
                    EOF
                '''
                // Deploys the package straight into the Nexus repository storage pool
                sh 'mvn deploy -DskipTests -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true'
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
                // Update image tags dynamically
                sh "sed -i 's|image: .*|image: ${REGISTRY_USER}/${IMAGE_NAME}:${IMAGE_TAG}|g' k8s/deployment.yaml"
                
                // CRITICAL FIX: Removed 'sudo'. Running native kubectl using mapped config permissions
                sh "kubectl apply -f k8s/deployment.yaml"
                sh "kubectl apply -f k8s/service.yaml"
            }
        }
    }
}
