module "functionapp-dev" {
  source      = "./modules/app"
  name_prefix = "dev"

}

module "functionapp-test" {
  source      = "./modules/app"
  name_prefix = "test"

}
