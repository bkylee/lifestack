# Module 1, Step 2 — resource groups 

I created the following files: variables, terraofmr.tfvars, resource_groups.tf, main.tf and locals.tf. I learned about the for each function in terraform. Leanred about the features block in main.tf. 

variables.tf stores the template for the values that terraform.tfvars accepts. 

for each uses each.key and each.value. We use this to create resource group blocks interatively rather than hard-coded. If we add or remove RG groups, we don't have to manually update code. 

feautures block is used to specify features/ behaviours for resources rather than for creating a resource.  

