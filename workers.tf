resource "aws_autoscaling_group" "workers" {
  name_prefix          = "${aws_eks_cluster.this.name}-${lookup(var.worker_groups[count.index], "name", count.index)}"
  desired_capacity     = "${lookup(var.worker_groups[count.index], "asg_desired_capacity", lookup(var.workers_group_defaults, "asg_desired_capacity"))}"
  max_size             = "${lookup(var.worker_groups[count.index], "asg_max_size",lookup(var.workers_group_defaults, "asg_max_size"))}"
  min_size             = "${lookup(var.worker_groups[count.index], "asg_min_size",lookup(var.workers_group_defaults, "asg_min_size"))}"
  min_elb_capacity     = "${lookup(var.worker_groups[count.index], "asg_min_size",lookup(var.workers_group_defaults, "asg_min_size"))}"
  launch_configuration = "${element(aws_launch_configuration.workers.*.id, count.index)}"
  vpc_zone_identifier  = ["${split(",", coalesce(lookup(var.worker_groups[count.index], "subnets", ""), join(",", var.subnets)))}"]
  enabled_metrics      = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  count                = "${length(var.worker_groups)}"

  tags = ["${concat(
    list(
      map("key", "Name", "value", "${aws_eks_cluster.this.name}-${lookup(var.worker_groups[count.index], "name", count.index)}-eks_asg", "propagate_at_launch", true),
      map("key", "kubernetes.io/cluster/${aws_eks_cluster.this.name}", "value", "owned", "propagate_at_launch", true),
    ),
    local.asg_tags)
  }"]

  lifecycle {
    ignore_changes = ["desired_capacity"]
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "workers" {
  name_prefix                 = "${aws_eks_cluster.this.name}-${lookup(var.worker_groups[count.index], "name", count.index)}"
  associate_public_ip_address = "${lookup(var.worker_groups[count.index], "public_ip", lookup(var.workers_group_defaults, "public_ip"))}"
  security_groups             = ["${concat(list(local.worker_security_group_id), var.worker_additional_security_group_ids)}"]
  iam_instance_profile        = "${aws_iam_instance_profile.workers.id}"
  image_id                    = "${lookup(var.worker_groups[count.index], "ami_id", data.aws_ami.eks_worker.id)}"
  instance_type               = "${lookup(var.worker_groups[count.index], "instance_type", lookup(var.workers_group_defaults, "instance_type"))}"
  key_name                    = "${lookup(var.worker_groups[count.index], "key_name", lookup(var.workers_group_defaults, "key_name"))}"
  user_data_base64            = "${base64encode(element(data.template_file.userdata.*.rendered, count.index))}"
  ebs_optimized               = "${lookup(var.worker_groups[count.index], "ebs_optimized", lookup(local.ebs_optimized, lookup(var.worker_groups[count.index], "instance_type", lookup(var.workers_group_defaults, "instance_type")), false))}"
  count                       = "${length(var.worker_groups)}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_size           = "${lookup(var.worker_groups[count.index], "root_volume_size", lookup(var.workers_group_defaults, "root_volume_size"))}"
    volume_type           = "${lookup(var.worker_groups[count.index], "root_volume_type", lookup(var.workers_group_defaults, "root_volume_type"))}"
    iops                  = "${lookup(var.worker_groups[count.index], "root_iops", lookup(var.workers_group_defaults, "root_iops"))}"
    delete_on_termination = true
  }
}

resource "aws_autoscaling_policy" "workers-cpu" {
  count                  = "${length(var.worker_groups)}"
  name                   = "${aws_eks_cluster.this.name}-${lookup(var.worker_groups[count.index], "name", count.index)}-scaling-policy-wg-${count.index}"
  autoscaling_group_name = "${aws_autoscaling_group.workers.*.name[count.index]}"
  policy_type            = "TargetTrackingScaling"
  estimated_instance_warmup = 60

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 40.0
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "workers" {
  name_prefix = "${aws_eks_cluster.this.name}"
  description = "Security group for all nodes in the cluster."
  vpc_id      = "${var.vpc_id}"
  count       = "${var.worker_create_security_group ? 1 : 0}"
  tags        = "${merge(var.tags, map("Name", "${aws_eks_cluster.this.name}-eks_worker_sg", "kubernetes.io/cluster/${aws_eks_cluster.this.name}", "owned"
  ))}"
}

resource "aws_security_group_rule" "workers_egress_internet" {
  description       = "Allow nodes all egress to the Internet."
  protocol          = "-1"
  security_group_id = "${aws_security_group.workers.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
  count             = "${var.worker_create_security_group ? 1 : 0}"
}

resource "aws_security_group_rule" "workers_ingress_self" {
  description              = "Allow node to communicate with each other."
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
  count                    = "${var.worker_create_security_group ? 1 : 0}"
}

resource "aws_security_group_rule" "workers_ingress_cluster" {
  description              = "Allow workers Kubelets and pods to receive communication from the cluster control plane."
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${local.cluster_security_group_id}"
  from_port                = "${var.worker_sg_ingress_from_port}"
  to_port                  = 65535
  type                     = "ingress"
  count                    = "${var.worker_create_security_group ? 1 : 0}"
}

resource "aws_security_group_rule" "workers_ingress_cluster_https" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane."
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${local.cluster_security_group_id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
  count                    = "${var.worker_create_security_group ? 1 : 0}"
}

resource "aws_iam_role" "workers" {
  name_prefix        = "${aws_eks_cluster.this.name}"
  assume_role_policy = "${data.aws_iam_policy_document.workers_assume_role_policy.json}"
}

resource "aws_iam_instance_profile" "workers" {
  name_prefix = "${aws_eks_cluster.this.name}"
  role        = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_CloudwatchPutMetric" {
  policy_arn = "arn:aws:iam::140222353192:policy/cloudwatch-putmetric"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonElasticFileSystemReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemReadOnlyAccess"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.workers.name}"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.workers.name}"
}

resource "null_resource" "tags_as_list_of_maps" {
  count = "${length(keys(var.tags))}"

  triggers = "${map(
    "key", "${element(keys(var.tags), count.index)}",
    "value", "${element(values(var.tags), count.index)}",
    "propagate_at_launch", "true"
  )}"
}
