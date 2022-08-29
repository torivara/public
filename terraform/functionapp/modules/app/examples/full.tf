module "functionapp" {
  source = "./modules/app"

  name_prefix               = "p"
  app_insights_workspace_id = "your-workspace-id"
  location                  = "norwayeast"
  app_name                  = "myapp"
  os_type                   = "Linux"
  sku_name                  = "S2"

}
