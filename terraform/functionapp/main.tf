module "functionapp" {
  source = "./modules/app"

  os_type  = "Linux"
  sku_name = "B1"

}
