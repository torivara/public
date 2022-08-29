module "functionapp" {
  source = "./modules/app"

  app_insights_workspace_id = "your-workspace-id"

}
