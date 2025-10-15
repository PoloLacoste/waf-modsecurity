# docker-bake.hcl

variable "coreruleset-version" {
  # renovate: depName=coreruleset/coreruleset datasource=github-releases
  default = "4.9.0"
}

variable "coreruleset-docker-version" {
  # renovate: depName=coreruleset/modsecurity-crs-docker datasource=github-releases
  default = "20241202"
}

variable "modsecurity-version" {
  # renovate: depName=ModSecurity3 packageName=owasp-modsecurity/ModSecurity datasource=github-releases
  default = "3.0.13"
}

variable "lua-version" {
  default = "5.3"
}

variable "lua-modules" {
  default = [
    "lua-lzlib",
    "lua-socket"
  ]
}

group "default" {
  targets = [
    "alpine"
  ]
}

target "alpine" {
  context="."    
  args = {
    CRS_VERSION = "${coreruleset-version}"
    CRS_DOCKER_VERSION = "${coreruleset-docker-version}"
    MODSECURITY_VERSION = "${modsecurity-version}"
    LUA_VERSION = "${lua-version}"
    LUA_MODULES = join(" ", lua-modules)
  }
  tags = ["pololacoste/waf-modsecurity:latest"]
}