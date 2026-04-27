variable "project_id" {
  type = string
}

variable "create_wi_bindings" {
  type    = bool
  default = true
  description = "Set to false on first apply before GKE exists; set to true after GKE creates the WI pool."
}
