
## Locals block in Terraform

A `locals` block is used to declare local values in Terraform:

```hcl
locals {
  env    = "dev"
  region = "us-east-1"
}
```

When you want to use those values elsewhere, reference them through the `local` object, not through `locals`:

```hcl
provider "aws" {
  region = local.region
}
```

The difference is:

- `locals { ... }` defines the local values.
- `local.<name>` reads a local value.

So the correct pattern is to declare locals with `locals { ... }` and read them with `local.region`, `local.env`, and so on.

## Output block in Terraform

When a resource is created through a module, its values are not automatically available to other modules or root-level resources. To make a value accessible outside the module, we expose it with an `output` block.

For example, if a VPC is created in a VPC module, and another resource such as a subnet is created in a different module, the VPC ID must first be exposed by the VPC module:

```hcl
output "vpc_id" {
  value = aws_vpc.vpc.id
}
```

That exported value can then be consumed from the root module through `module.vpc_1.vpc_id` (or the corresponding module name and output name).

