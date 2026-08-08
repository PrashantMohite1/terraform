
# Locals block in Terraform

A `locals` block is used to declare local values in Terraform:

```hcl
locals {
  env    = "dev"
  region = "us-east-1"
}
```

When using those values elsewhere, reference them through the `local` object (singular), not `locals`:

```hcl
provider "aws" {
  region = local.region
}
```

The distinction is:

- `locals { ... }` defines the local values.
- `local.<name>` reads a local value.

So, the correct usage is `locals { ... }` for declaration and `local.region` or `local.env` for access.