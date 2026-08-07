config {
  # Modules are linted directly (tflint --recursive walks into them), so there
  # is no need to also follow module calls from the environment stacks.
  call_module_type = "none"
  force            = false
}

# The Terraform ruleset ships with tflint itself, so there is no plugin
# download to pin. There is no official OCI ruleset; provider-specific checks
# for OCI are covered by checkov instead.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Naming convention: snake_case everywhere.
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Every module input and output carries a description — these modules are meant
# to be read by someone who did not write them.
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Off by design: the environment stacks pass most values through from tfvars,
# and requiring a default on every variable would hide missing required inputs.
rule "terraform_standard_module_structure" {
  enabled = false
}
