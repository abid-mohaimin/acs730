# Task 6: the application secret.
#
# The parameter is created ONCE, by hand, before the first plan:
#   aws ssm put-parameter --name /acs730/a1/<env>/db_password \
#     --type SecureString --value '<placeholder>'
#
# Terraform only READS it. There is deliberately no aws_ssm_parameter
# resource anywhere in this configuration: creating and reading the same
# name in one graph is circular and fails on a fresh environment.

data "aws_ssm_parameter" "db_password" {
  name            = var.db_password_parameter_name
  with_decryption = true
}
