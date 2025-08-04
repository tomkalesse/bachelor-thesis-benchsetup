variable "project_id" {
  description = "The ID of the Stackit project to use for resources."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to resources for management."
  type        = map(string)
  default = {
    "managedby" = "terraform"
  }
}
