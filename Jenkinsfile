pipeline {
    agent any
    environment {
        REGISTRY_USER = 'bhanutejaravutla' 
        IMAGE_NAME    = 'secured-app'
        IMAGE_TAG     = "${BUILD_NUMBER}"
    }
    stages {
        stage('Initialize & Clean Workspace') {
            steps {
                echo 'Cleaning up any corrupted artifacts from prior runs...'
                // Restores the original checked-out pom.xml back to its clean Git baseline
                sh 'git checkout pom.xml || true'
            }
        }

        stage('Artifact Package Compilation') {
            steps {
                echo 'Compiling artifact and caching dependencies to local ~/.m2 directory...'
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Upload to Nexus Repository') {
            steps {
                echo 'Injecting repository targets and uploading artifact package to Nexus...'
                
                // SAFE INJECTION: Replaces the closing </project> tag with the block inside the tag bounds
                sh '''
                sed -i 's|</project>|  <distributionManagement><repository><id>nexus-releases</id><url>http://localhost:8081/repository/maven-releases/</url></repository><snapshotRepository><id>nexus-snapshots</id><url>http://localhost:8081/repository/maven-snapshots/</url></snapshotRepository></distributionManagement>\n</project>|g' pom.xml
                '''
                
                // Deploys the package straight into the Nexus repository storage pool
                sh 'mvn deploy -DskipTests -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true'
            }
        }

        stage('Trivy FS Scan') {
            steps {
                echo 'Scanning compiled project filesystem using local cache bounds...'
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
                sh "kubectl apply -f k8s/deployment.yaml"
                sh "kubectl apply -f k8s/service.yaml"
            }
        }
    }
}
