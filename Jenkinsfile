pipeline {

    agent any

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
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh 'terraform plan'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Get EC2 IP') {
            steps {
                script {
                    env.EC2_IP = sh(
                        script: 'cd terraform && terraform output -raw ec2_public_ip',
                        returnStdout: true
                    ).trim()

                    echo "EC2 Public IP: ${env.EC2_IP}"
                }
            }
        }

        stage('Create Ansible Inventory') {
            steps {
                sh '''
                cat > ansible/inventory/hosts.ini <<EOF
[postgres]
postgres-server ansible_host=${EC2_IP}

[postgres:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=/home/jenkins/.ssh/postgres-key.pem
ansible_python_interpreter=/usr/bin/python3
EOF
                '''
            }
        }

        stage('Wait for SSH') {
            steps {
                sh '''
                echo "Waiting for EC2 SSH..."

                for i in {1..20}; do
                    if ssh -o StrictHostKeyChecking=no \
                        -o ConnectTimeout=5 \
                        -i /home/jenkins/.ssh/postgres-key.pem \
                        ec2-user@${EC2_IP} "echo SSH Ready"; then
                        break
                    fi

                    echo "Waiting..."
                    sleep 10
                done
                '''
            }
        }

        stage('Ansible PostgreSQL') {
            steps {
                sh '''
                ansible-playbook \
                    -i ansible/inventory/hosts.ini \
                    ansible/playbooks/postgres.yml
                '''
            }
        }

        stage('PostgreSQL Validation') {
            steps {
                sh '''
                ansible \
                    -i ansible/inventory/hosts.ini \
                    postgres \
                    -m shell \
                    -a "systemctl is-active postgresql"
                '''
            }
        }
    }

    post {
        success {
            echo "PostgreSQL infrastructure deployed successfully!"
            echo "EC2 Public IP: ${EC2_IP}"
        }

        failure {
            echo "Deployment failed. Check the Jenkins console output."
        }
    }
}