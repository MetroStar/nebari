resource "keycloak_realm" "realm-master" {
  provider = keycloak
  
  realm = "qhub"

  display_name = "QHub ${var.name}"

  smtp_server {
    host = "smtp.gmail.com"
    from = "email@test.com"

    auth {
      username = "email@test.com"
      password = "<password>"
    }
  }
}
