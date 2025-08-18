variable "subscription_id" {
  type = string
}
variable "location" {
  type    = string
  default = "westus2"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "name_prefix" {
  type    = string
  default = "aaimadev"
}
