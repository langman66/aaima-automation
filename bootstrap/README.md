# Bootstrap remote state for aaima

This folder creates the Terraform remote state storage account/container.
It uses **local state** for the bootstrap only. After it completes, copy the
values into `infra/envs/dev/backend.hcl` (already pre-filled with names).

> Note: The state storage account is left with public network access enabled
> so GitHub-hosted runners can reach it. You can later move to private
> networking with self-hosted runners if desired.
