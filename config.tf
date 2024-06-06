terraform {
    required_providers {
        yandex = {
            source = "yandex-cloud/yandex"
        }
    }
}
  
provider "yandex" {
    zone      = "ru-central1-a"
}

# DATABASE END

resource "yandex_ydb_database_serverless" "devops-db" {
    name = "devops-db"
}

resource "yandex_ydb_table" "leads" {
    path = "root/leads"
    connection_string = yandex_ydb_database_serverless.devops-db.ydb_full_endpoint

    column {
        name = "id"
        type = "String"
        not_null = true
    }
    column {
        name = "description"
        type = "String"
    }
    column {
        name = "name"
        type = "String"
    }
    column {
        name = "status"
        type = "String"
    }
    column {
        name = "is_final"
        type = "Bool"
    }

    primary_key = ["id"]

}

# MICRO SERVICE

resource "yandex_function" "get-leads-function" {
    name = "get-leads"
    user_hash = "12233355346"
    runtime = "python312"
    entrypoint = "get-leads.handler"
    memory = "128"
    execution_timeout  = "10"
    service_account_id = "ajej49bir0o8t19q8i1g"

    environment = {
        endpoint = "grpcs://${yandex_ydb_database_serverless.devops-db.ydb_api_endpoint}"
        database = "${yandex_ydb_database_serverless.devops-db.database_path}"
    }
    content {
        zip_filename = "${path.module}/get-leads.zip"
    }
}

resource "yandex_function" "create-function" {
    name = "create"
    user_hash = "13323245556"
    runtime = "python312"
    entrypoint = "create.handler"
    memory = "128"
    execution_timeout  = "10"
    service_account_id = "ajej49bir0o8t19q8i1g"

    environment = {
        endpoint = "grpcs://${yandex_ydb_database_serverless.devops-db.ydb_api_endpoint}"
        database = "${yandex_ydb_database_serverless.devops-db.database_path}"
    }
    content {
        zip_filename = "${path.module}/create.zip"
    }
}

resource "yandex_function" "delete-function" {
    name = "delete"
    user_hash = "123233355556"
    runtime = "python312"
    entrypoint = "delete.handler"
    memory = "128"
    execution_timeout  = "10"
    service_account_id = "ajej49bir0o8t19q8i1g"

    environment = {
        endpoint = "grpcs://${yandex_ydb_database_serverless.devops-db.ydb_api_endpoint}"
        database = "${yandex_ydb_database_serverless.devops-db.database_path}"
    }
    content {
        zip_filename = "${path.module}/delete.zip"
    }
}

resource "yandex_function" "delete-all-function" {
    name = "delete-all"
    user_hash = "12352546"
    runtime = "python312"
    entrypoint = "delete-all.handler"
    memory = "128"
    execution_timeout  = "10"
    service_account_id = "ajej49bir0o8t19q8i1g"

    environment = {
        endpoint = "grpcs://${yandex_ydb_database_serverless.devops-db.ydb_api_endpoint}"
        database = "${yandex_ydb_database_serverless.devops-db.database_path}"
    }
    content {
        zip_filename = "${path.module}/delete-all.zip"
    }
}

resource "yandex_function" "update-lead-function" {
    name = "update-lead"
    user_hash = "14525556"
    runtime = "python312"
    entrypoint = "update-lead.handler"
    memory = "128"
    execution_timeout  = "10"
    service_account_id = "ajej49bir0o8t19q8i1g"

    environment = {
        endpoint = "grpcs://${yandex_ydb_database_serverless.devops-db.ydb_api_endpoint}"
        database = "${yandex_ydb_database_serverless.devops-db.database_path}"
    }
    content {
        zip_filename = "${path.module}/update-lead.zip"
    }
}

# API GATEWAY

resource "yandex_api_gateway" "api-gateway" {
    name = "api-gateway"
    spec = <<-EOT
    openapi: 3.0.0
    info:
        title: Sample API
        version: 1.0.0

    x-yc-apigateway:
        cors:
            origin: '*'
            methods: 'POST'

    paths:
        /create:
            post:
                x-yc-apigateway-integration:
                    type: cloud-functions
                    function_id: ${yandex_function.create-function.id}
                    service_account_id: ajej49bir0o8t19q8i1g
                operationId: create
        /delet:
            post:
                x-yc-apigateway-integration:
                    type: cloud-functions
                    function_id: ${yandex_function.delete-function.id}
                    service_account_id: ajej49bir0o8t19q8i1g
                operationId: delete
        /get-leads:
            post:
                x-yc-apigateway-integration:
                    type: cloud-functions
                    function_id: ${yandex_function.get-leads-function.id}
                    service_account_id: ajej49bir0o8t19q8i1g
                operationId: get-leads
        /update-lead:
            post:
                x-yc-apigateway-integration:
                    type: cloud-functions
                    function_id: ${yandex_function.update-lead-function.id}
                    service_account_id: ajej49bir0o8t19q8i1g
                operationId: update-lead
        /delet-all:
            post:
                x-yc-apigateway-integration:
                    type: cloud-functions
                    function_id: ${yandex_function.delete-all-function.id}
                    service_account_id: ajej49bir0o8t19q8i1g
                operationId: delete-all
    EOT
}

# FRONT END

data "yandex_compute_image" "container-optimized-image" {
    family = "container-optimized-image"
}

resource "yandex_compute_instance" "frontend" {
    name = "frontend"
    platform_id = "standard-v1"
    service_account_id = "ajekoim11d0cdpdlt3ns"

    resources {
        cores  = 2
        memory = 2
        core_fraction = 20
    }

    boot_disk {
        initialize_params {
            image_id = data.yandex_compute_image.container-optimized-image.id
        }
    }

    network_interface {
        subnet_id = yandex_vpc_subnet.subnet-1.id
        nat = true
    }

    metadata = {
        docker-compose = <<EOT
        version: '3.7'
        services:
            app1:
                container_name: frontend
                image: "cr.yandex/crpk3rpmfiosc6kehjf3/kanban:latest"
                ports:
                - "80:80"
                restart: always
                environment:
                    MY_APP_BACKEND_ORIGIN: "https://${yandex_api_gateway.api-gateway.domain}"
        EOT
        user-data = <<-EOT
        datasource:
            Ec2:
                strict_id: false
        ssh_pwauth: no
        users:
        - name: roaoch
            sudo: ALL=(ALL) NOPASSWD:ALL
            shell: /bin/bash
            ssh_authorized_keys:
            - ${file("id_rsa.pub")}
        EOT
    }
}

resource "yandex_vpc_network" "network-1" {
    name = "devops-network"
}
 
resource "yandex_vpc_subnet" "subnet-1" {
    name = "devops-subnet"
    zone = "ru-central1-a"
    network_id = "${yandex_vpc_network.network-1.id}"
    v4_cidr_blocks = ["10.2.0.0/16"]
}

output "external_ip" {
    value = yandex_compute_instance.frontend.network_interface.0.nat_ip_address
}