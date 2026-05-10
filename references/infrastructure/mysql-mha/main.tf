terraform {
  required_providers {
    mysql = {
      source  = "petoju/mysql"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.0"
}

provider "mysql" {
  endpoint = var.mysql_endpoint
  username = var.mysql_username
  password = var.mysql_password
}

variable "mysql_endpoint" {
  description = "MySQL endpoint"
  type = string
}

variable "mysql_username" {
  description = "MySQL username"
  type = string
}

variable "mysql_password" {
  description = "MySQL password"
  type = string
  sensitive = true
}

variable "kosa_password" {
  description = "KOSA user password"
  type = string
  sensitive = true
}

resource "mysql_database" "kosa" {
  name = "kosa"
}

resource "mysql_user" "kosa" {
  user               = "kosa"
  plaintext_password = var.kosa_password
  host               = "%"
}

resource "mysql_grant" "kosa" {
  user       = mysql_user.kosa.user
  database   = mysql_database.kosa.name
  privileges = ["ALL"]
  host       = "%"
}

resource "mysql_user" "replication" {
  user               = "replication"
  plaintext_password = var.mysql_password
  host               = "%"
}

resource "mysql_grant" "replication" {
  user       = mysql_user.replication.user
  database   = "*"
  privileges = ["REPLICATION CLIENT", "REPLICATION SLAVE"]
  host       = "%"
}