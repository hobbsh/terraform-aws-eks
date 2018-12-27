variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as a prefix in names of related resources."
}

variable "cluster_security_group_id" {
  description = "If provided, the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the workers and provide API access to your current IP/32."
  default     = ""
}

variable "workstation_cidr" {
  description = "Override the default ingress rule that allows communication with the EKS cluster API. If not given, will use current IP/32. "
  default     = ""
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster."
  default     = "1.11"
}

variable "config_output_path" {
  description = "Determines where config files are placed if using configure_kubectl_session and you want config files to land outside the current working directory. Should end in a forward slash / ."
  default     = "./"
}

variable "write_kubeconfig" {
  description = "Whether to write a kubeconfig file containing the cluster configuration."
  default     = true
}

variable "manage_aws_auth" {
  description = "Whether to write and apply the aws-auth configmap file."
  default     = true
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
  type        = "list"
  default     = []
}

variable "map_accounts_count" {
  description = "The count of accounts in the map_accounts list."
  type        = "string"
  default     = 0
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
  type        = "list"
  default     = []
}

variable "map_roles_count" {
  description = "The count of roles in the map_roles list."
  type        = "string"
  default     = 0
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
  type        = "list"
  default     = []
}

variable "map_users_count" {
  description = "The count of roles in the map_users list."
  type        = "string"
  default     = 0
}

variable "subnets" {
  description = "A list of subnets to place the EKS cluster and workers within."
  type        = "list"
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = "map"
  default     = {}
}

variable "vpc_id" {
  description = "VPC where the cluster and workers will be deployed."
}

variable "worker_groups" {
  description = "A list of maps defining worker group configurations. See workers_group_defaults for valid keys."
  type        = "list"

  default = [{
    "name" = "default"
  }]
}

variable "workers_group_defaults" {
  description = "Default values for target groups as defined by the list of maps."
  type        = "map"

  default = {
    name                 = "count.index" # Name of the worker group. Literal count.index will never be used but if name is not set, the count.index interpolation will be used.
    ami_id               = ""            # AMI ID for the eks workers. If none is provided, Terraform will search for the latest version of their EKS optimized worker AMI.
    asg_desired_capacity = "0"           # Desired worker capacity in the autoscaling group.
    asg_max_size         = "0"           # Maximum worker capacity in the autoscaling group.
    asg_min_size         = "0"           # Minimum worker capacity in the autoscaling group.
    instance_type        = "m4.large"    # Size of the workers instances.
    root_volume_size     = "20"          # root volume size of workers instances.
    root_volume_type     = "gp2"         # root volume type of workers instances, can be 'standard', 'gp2', or 'io1'
    root_iops            = "0"           # The amount of provisioned IOPS. This must be set with a volume_type of "io1".
    key_name             = ""            # The key name that should be used for the instances in the autoscaling group
    pre_userdata         = ""            # userdata to pre-append to the default userdata.
    additional_userdata  = ""            # userdata to append to the default userdata.
    ebs_optimized        = true          # sets whether to use ebs optimization on supported types.
    public_ip            = false         # Associate a public ip address with a worker
    kubelet_node_labels  = ""            # This string is passed directly to kubelet via --node-lables= if set. It should be comma delimited with no spaces. If left empty no --node-labels switch is added.
    subnets              = ""            # A comma delimited string of subnets to place the worker nodes in. i.e. subnet-123,subnet-456,subnet-789
  }
}

variable "worker_security_group_id" {
  description = "If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster."
  default     = ""
}

variable "worker_additional_security_group_ids" {
  description = "Will append provided security group IDs to the workers to complement the security groups created by this module or provided by worker_security_group_id"
  default     = []
}

variable "worker_sg_ingress_from_port" {
  description = "Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80, or 443)."
  default     = "1025"
}

variable "kubeconfig_aws_authenticator_command" {
  description = "Command to use to to fetch AWS EKS credentials."
  default     = "aws-iam-authenticator"
}

variable "kubeconfig_aws_authenticator_additional_args" {
  description = "Any additional arguments to pass to the authenticator such as the role to assume. e.g. [\"-r\", \"MyEksRole\"]."
  type        = "list"
  default     = []
}

variable "kubeconfig_aws_authenticator_env_variables" {
  description = "Environment variables that should be used when executing the authenticator. e.g. { AWS_PROFILE = \"eks\"}."
  type        = "map"
  default     = {}
}

variable "kubeconfig_name" {
  description = "Override the default name used for items kubeconfig."
  default     = ""
}

variable "cluster_create_timeout" {
  description = "Timeout value when creating the EKS cluster."
  default     = "15m"
}

variable "cluster_delete_timeout" {
  description = "Timeout value when deleting the EKS cluster."
  default     = "15m"
}

variable "local_exec_interpreter" {
  description = "Command to run for local-exec resources. Must be a shell-style interpreter. If you are on Windows Git Bash is a good choice."
  type        = "list"
  default     = ["/bin/sh", "-c"]
}

variable "cluster_create_security_group" {
  description = "Whether to create a security group for the cluster or attach the cluster to `cluster_security_group_id`."
  default     = true
}

variable "worker_create_security_group" {
  description = "Whether to create a security group for the workers or attach the workers to `worker_security_group_id`."
  default     = true
}
