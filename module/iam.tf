locals {
  cluster_name = var.cluster-name
}

resource "random_integer" "random_suffix" {
  min = 1000
  max = 9999
}

resource "aws_iam_role" "eks-cluster-role" {
  count = var.is_eks_role_enabled ? 1 : 0
  name  = "${local.cluster_name}-role-${random_integer.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  count      = var.is_eks_role_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster-role[count.index].name
}

resource "aws_iam_role" "eks-nodegroup-role" {
  count = var.is_eks_nodegroup_role_enabled ? 1 : 0
  name  = "${local.cluster_name}-nodegroup-role-${random_integer.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_policies" {
  for_each = var.is_eks_nodegroup_role_enabled ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]) : []

  role       = aws_iam_role.eks-nodegroup-role[0].name
  policy_arn = each.value
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecddee2b"]
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_irsa" {
  name               = "${local.cluster_name}-ebs-csi-irsa"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"

  service_account_role_arn = aws_iam_role.ebs_csi_irsa.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.this
  ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.this
  ]
}


# resource "aws_iam_role_policy_attachment" "eks-AmazonWorkerNodePolicy" {
#   count      = var.is_eks_nodegroup_role_enabled ? 1 : 0
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.eks-nodegroup-role[count.index].name
# }

# resource "aws_iam_role_policy_attachment" "eks-AmazonEKS_CNI_Policy" {
#   count      = var.is_eks_nodegroup_role_enabled ? 1 : 0
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.eks-nodegroup-role[count.index].name
# }
# resource "aws_iam_role_policy_attachment" "eks-AmazonEC2ContainerRegistryReadOnly" {
#   count      = var.is_eks_nodegroup_role_enabled ? 1 : 0
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.eks-nodegroup-role[count.index].name
# }

# resource "aws_iam_role_policy_attachment" "eks-AmazonEBSCSIDriverPolicy" {
#   count      = var.is_eks_nodegroup_role_enabled ? 1 : 0
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
#   role       = aws_iam_role.eks-nodegroup-role[count.index].name
# }

# # OIDC
# resource "aws_iam_role" "eks_oidc" {
#   assume_role_policy = data.aws_iam_policy_document.eks_oidc_assume_role_policy.json
#   name               = "eks-oidc"
# }

# resource "aws_iam_policy" "eks-oidc-policy" {
#   name = "test-policy"

#   policy = jsonencode({
#     Statement = [{
#       Action = [
#         "s3:ListAllMyBuckets",
#         "s3:GetBucketLocation",
#         "*"
#       ]
#       Effect   = "Allow"
#       Resource = "*"
#     }]
#     Version = "2012-10-17"
#   })
# }

# resource "aws_iam_role_policy_attachment" "eks-oidc-policy-attach" {
#   role       = aws_iam_role.eks_oidc.name
#   policy_arn = aws_iam_policy.eks-oidc-policy.arn
# }
