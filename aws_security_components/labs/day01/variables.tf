variable "region" {
  description = "AWS region. MUST match labs/base's region — this module layers onto the base task role in that same region/account."
  type        = string
  default     = "us-east-1"
}

variable "app_object_prefix" {
  description = <<-EOT
    Object-key prefix this lab treats as "what the app actually uses"
    inside the app_data bucket. labs/base/iam.tf's design comment states
    the app only ever needs Get/Put on a single prefix, but the shipped
    app.py stub (see labs/base/app/app.py) does not yet implement any S3
    object read/write itself — APP_BUCKET is passed in as an env var but
    unused today. This variable is this lab's stated convention for that
    documented intent, so the tightened policy has a concrete prefix to
    enforce. If you extend app.py to actually read/write objects, keep
    it inside this prefix or the tightened policy will start rejecting
    real app traffic.
  EOT
  type        = string
  default     = "app-data"
}

variable "base_state_path" {
  description = "Path to labs/base's local state file, relative to this module. Base must be applied first."
  type        = string
  default     = "../base/terraform.tfstate"
}
