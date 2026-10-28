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

        stage('Generate Ansible Inventory') {
            steps {
                sh '''
                    cat > ansible/inventory/hosts.ini <<EOF
[postgres]
postgres-server ansible_host=${EC2_IP}

[postgres:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
                '''
            }
        }

        stage('Run Ansible') {
            steps {

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'postgres-ec2-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {

                    sh '''
                       ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook \
                       -i ansible/inventory/hosts.ini \
                       -u ec2-user \
                       --private-key "$SSH_KEY" \
                       ansible/playbooks/postgres.yml
                    '''
                }
            }
        }

        stage('Validate PostgreSQL') {
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
    }

    post {

        success {
            echo "======================================"
            echo "PostgreSQL deployment successful!"
            echo "EC2 IP: ${EC2_IP}"
            echo "======================================"
        }

        failure {
            echo "PostgreSQL deployment failed."
            echo "Check the Jenkins console output."
        }
    }
}