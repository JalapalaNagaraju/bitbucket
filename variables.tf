variable "location" {
  description = "Azure region (WestUS, CentralUs, AustraliaEast, etc) shared by all of the resources in the template"
  type        = string
  default     = "West Europe"
}

variable "_artifactsLocation" {
  description = "The base URI where artifacts required by this template are located"
  type        = string
  default     = "Deleteme"
}

variable "_artifactsLocationSasToken" {
  description = "The sasToken required to access _artifactsLocation. When the template is deployed using the accompanying scripts, a sasToken will be automatically generated. Use the defaultValue if the staging location is not secured."
  type        = string
  default     = "Deleteme"
}

variable "vnetCIDR" {
  description = "Address space for the Virtual Network created by the template"
  type        = string
  default     = "10.0.0.0/16"
}

variable "publicNetCIDR" {
  description = "Address space for the public subnet in the vnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "appgwNetCIDR" {
  description = "Address space for the private subnet with Application Gateways"
  type        = string
  default     = "10.0.2.0/24"
}

variable "sshUserName" {
  description = "Username for SSH access to Bitbucket Server nodes as well as for the jumpbox"
  type        = string
  default     = "ubuntu"
}

variable "bbsNetCIDR" {
  description = "Address space for the private subnet where Bitbucket Server nodes are deployed"
  type        = string
  default     = "10.0.4.0/24"
}

variable "esNetCIDR" {
  description = "Address space for the private subnet where Elasticsearch nodes are deployed"
  type        = string
  default     = "10.0.5.0/24"
}

variable "sshKey" {
  description = "SSH key to allow access to jumpbox"
  type        = string
  default     = "testkey"
}

variable "jumpboxSize" {
  description = "The size of jumpbox VM"
  type        = string
  default     = "Standard_B1s"
}

variable "bbsHttpPort" {
  description = "Internal port that Bitbucket Server uses to accept HTTP connections"
  type        = number
  default     = 7990
}

variable "bbsHazelcastPort" {
  description = "Internal port that Bitbucket Server uses for Hazelcast communication"
  type        = number
  default     = 5701
}

variable "linuxOsType" {
  description = "Select your preferred Linux OS type. Bear in mind, the Linux OS type has to support Accelerated Networking as well - https://docs.microsoft.com/en-us/azure/virtual-network/create-vm-accelerated-networking-cli"
  type        = list
  default = [
    "Canonical:UbuntuServer:16.04-LTS",
    "Canonical:UbuntuServer:18.04-LTS",
    "RedHat:RHEL:7.5",
    "OpenLogic:CentOS:7.5",
    "credativ:Debian:9-backports"
  ]
}

