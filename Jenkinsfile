
pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'DESTROY_INFRA',
            defaultValue: false,
            description: 'Tick this checkbox to destroy the Terraform-managed infrastructure'
        )
    }

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Validate') {
            when {
                expression { !params.DESTROY_INFRA }
            }
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression { !params.DESTROY_INFRA }
            }
            steps {
                dir('terraform') {
                    sh 'terraform plan'
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { !params.DESTROY_INFRA }
            }
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Read Terraform Outputs') {
            when {
                expression { !params.DESTROY_INFRA }
            }
            steps {
                script {
                    env.APP_IP = sh(
                        script: 'cd terraform && terraform output -raw app_public_ip',
                        returnStdout: true
                    ).trim()

                    env.DB_IP = sh(
                        script: 'cd terraform && terraform output -raw db_private_ip',
                        returnStdout: true
                    ).trim()

                    env.ALB_DNS = sh(
                        script: 'cd terraform && terraform output -raw alb_dns_name',
                        returnStdout: true
                    ).trim()

                    echo "App (jump host) public IP: ${env.APP_IP}"
                    echo "DB private IP: ${env.DB_IP}"
                    echo "ALB DNS: ${env.ALB_DNS}"
                }
            }
        }

        stage('Configure PostgreSQL') {
            when {
                expression { !params.DESTROY_INFRA }
            }
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'postgres-ec2-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -e

                        # Inventory: DB has only a private IP, so SSH goes through the app EC2.
                        cat > ansible/inventory/hosts.ini <<EOF
[postgres]
postgres-db ansible_host=${DB_IP}

[postgres:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -q ${SSH_USER}@${APP_IP}"'
EOF

                        # DB credentials come from Terraform; keep them out of the console log.
                        umask 077
                        VARS_FILE="$(mktemp)"
                        trap 'rm -f "$VARS_FILE"' EXIT
                        DB_NAME="$(cd terraform && terraform output -raw db_name)"
                        DB_USER="$(cd terraform && terraform output -raw db_user)"
                        DB_PASSWORD="$(cd terraform && terraform output -raw db_password)"
                        printf 'db_name: "%s"\\ndb_user: "%s"\\ndb_password: "%s"\\n' \
                          "$DB_NAME" "$DB_USER" "$DB_PASSWORD" > "$VARS_FILE"

                        ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook \
                          -i ansible/inventory/hosts.ini \
                          -u "$SSH_USER" \
                          --private-key "$SSH_KEY" \
                          -e "@$VARS_FILE" \
                          ansible/playbooks/postgres.yml
                    '''
                }
            }
        }

        stage('Validate PostgreSQL') {
            when {
                expression { !params.DESTROY_INFRA }
            }
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'postgres-ec2-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        ansible \
                          -i ansible/inventory/hosts.ini \
                          -u "$SSH_USER" \
                          --private-key "$SSH_KEY" \
                          postgres \
                          -m shell \
                          -a "systemctl is-active postgresql"
                    '''
                }
            }
        }

        stage('Validate App via ALB') {
            when {
                expression { !params.DESTROY_INFRA }
            }
            steps {
                // The ALB needs a minute to mark the app healthy; retry for ~5 minutes.
                sh '''
                    for i in $(seq 1 30); do
                      if curl -fsS "http://${ALB_DNS}/api/status" | grep -q '"connected":true'; then
                        echo "App is reachable through the ALB and connected to PostgreSQL"
                        exit 0
                      fi
                      echo "Waiting for ALB / app / DB ($i/30)..."
                      sleep 10
                    done
                    echo "App did not report a DB connection in time"
                    exit 1
                '''
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.DESTROY_INFRA }
            }
            steps {
                dir('terraform') {
                    sh 'terraform plan -destroy'
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }

    post {
        success {
            script {
                if (params.DESTROY_INFRA) {
                    echo '======================================'
                    echo 'Infrastructure destroy completed!'
                    echo '======================================'
                } else {
                    echo '======================================'
                    echo 'Deployment successful!'
                    echo "Open the app: http://${env.ALB_DNS}"
                    echo "App / jump host IP: ${env.APP_IP}"
                    echo "DB private IP: ${env.DB_IP}"
                    echo '======================================'
                }
            }
        }

        failure {
            echo 'Pipeline failed. Check the Jenkins console output.'
        }
    }
}
