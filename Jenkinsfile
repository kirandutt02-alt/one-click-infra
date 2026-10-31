
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
    }

    parameters {
        booleanParam(
            name: 'DESTROY_INFRA',
            defaultValue: false,
            description: 'Select to destroy AWS infrastructure'
        )

        choice(
            name: 'INSTANCE_TYPE',
            choices: ['t3.micro', 't3.small', 't3.medium'],
            description: 'Select EC2 instance type'
        )

        string(
            name: 'DB_NAME',
            defaultValue: 'appdb',
            description: 'PostgreSQL database name'
        )

        string(
            name: 'DB_USER',
            defaultValue: 'appuser',
            description: 'PostgreSQL username'
        )
    }

    stages {

        // Get source code from GitHub
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // Initialize Terraform
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }

        // Create AWS infrastructure
        stage('Deploy Infrastructure') {
            when {
                expression { !params.DESTROY_INFRA }
            }

            steps {
                withEnv([
                    "TF_VAR_instance_type=${params.INSTANCE_TYPE}",
                    "TF_VAR_db_name=${params.DB_NAME}",
                    "TF_VAR_db_user=${params.DB_USER}"
                ]) {
                    dir('terraform') {
                        sh '''
                            set -e

                            terraform validate
                            terraform plan
                            terraform apply -auto-approve
                        '''
                    }
                }
            }
        }

        // Get Terraform outputs and configure PostgreSQL
        stage('Configure PostgreSQL') {
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
                }

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'postgres-ec2-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -e

                        # Create Ansible inventory
                        cat > ansible/inventory/hosts.ini <<EOF
[postgres]
postgres-db ansible_host=${DB_IP}

[postgres:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -q ${SSH_USER}@${APP_IP}"'
EOF

                        # Install required Ansible collection
                        ansible-galaxy collection install \
                            -r ansible/requirements.yml

                        # Create secure temporary variables file
                        umask 077
                        VARS_FILE=$(mktemp)
                        trap 'rm -f "$VARS_FILE"' EXIT

                        # Read Terraform outputs without printing secrets
                        python3 - "$VARS_FILE" <<'PY'
import json
import subprocess
import sys

result = subprocess.check_output(
    ["terraform", "-chdir=terraform", "output", "-json"],
    text=True
)

outputs = json.loads(result)

variables = {
    "db_name": outputs["db_name"]["value"],
    "db_user": outputs["db_user"]["value"],
    "db_password": outputs["db_password"]["value"]
}

with open(sys.argv[1], "w") as file:
    json.dump(variables, file)
PY

                        # Deploy PostgreSQL using Ansible role
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

        // Verify PostgreSQL installation
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

        // Verify application and database connectivity
        stage('Validate Application') {
            when {
                expression { !params.DESTROY_INFRA }
            }

            steps {
                sh '''
                    set -e

                    for i in $(seq 1 30); do

                        if curl -fsS "http://${ALB_DNS}/api/status" | grep -q '"connected":true'; then
                            echo "Application connected to PostgreSQL successfully!"
                            exit 0
                        fi

                        echo "Waiting for application and database... ($i/30)"
                        sleep 10
                    done

                    echo "Application validation failed!"
                    exit 1
                '''
            }
        }

        // Destroy all Terraform-managed infrastructure
        stage('Destroy Infrastructure') {
            when {
                expression { params.DESTROY_INFRA }
            }

            steps {
                withEnv([
                    "TF_VAR_instance_type=${params.INSTANCE_TYPE}",
                    "TF_VAR_db_name=${params.DB_NAME}",
                    "TF_VAR_db_user=${params.DB_USER}"
                ]) {
                    dir('terraform') {
                        sh '''
                            set -e

                            terraform plan -destroy
                            terraform destroy -auto-approve
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                if (params.DESTROY_INFRA) {
                    echo '================================'
                    echo 'Infrastructure destroyed!'
                    echo '================================'
                } else {
                    echo '================================'
                    echo 'PostgreSQL deployment successful!'
                    echo "Application URL: http://${env.ALB_DNS}"
                    echo "Jump Host IP: ${env.APP_IP}"
                    echo "Database Private IP: ${env.DB_IP}"
                    echo '================================'
                }
            }
        }

        failure {
            echo 'Pipeline failed! Check Jenkins console output.'
        }
    }
}
