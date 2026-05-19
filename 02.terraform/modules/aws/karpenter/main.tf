resource "aws_iam_role" "karpenter" {
  name = "${var.cluster_name}-karpenter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  policy_arn = each.value
  role       = aws_iam_role.karpenter.name
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "${var.cluster_name}-karpenter"
  role = aws_iam_role.karpenter.name

  tags = var.tags
}

resource "aws_ec2_tag" "subnet" {
  for_each = toset(var.subnet_ids)

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "security_group" {
  resource_id = var.security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_eks_access_entry" "karpenter" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.karpenter.arn
  type          = "EC2_LINUX"

  tags = var.tags
}