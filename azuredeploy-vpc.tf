# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=2.9.0"
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "bb_rg" {
  name     = "bitbucket_prod"
  location = var.location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet" {
  name                = "bb_vnet"
  resource_group_name = azurerm_resource_group.bb_rg.name
  location            = azurerm_resource_group.bb_rg.location
  address_space       = ["${var.vnetCIDR}"]
}



resource "azurerm_subnet" "public" {
  name                 = "public_subnet"
  resource_group_name  = azurerm_resource_group.bb_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["${var.publicNetCIDR}"]
}


resource "azurerm_subnet" "appgw" {
  name                 = "appgw_subnet"
  resource_group_name  = azurerm_resource_group.bb_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["${var.appgwNetCIDR}"]
}

resource "azurerm_subnet" "bb" {
  name                 = "bb_subnet"
  resource_group_name  = azurerm_resource_group.bb_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["${var.bbsNetCIDR}"]
}


resource "azurerm_subnet" "es" {
  name                 = "es_subnet"
  resource_group_name  = azurerm_resource_group.bb_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["${var.esNetCIDR}"]
}

resource "azurerm_route_table" "pub_rt" {
  name                = "public_routetable"
  resource_group_name = azurerm_resource_group.bb_rg.name
  location            = azurerm_resource_group.bb_rg.location
}

resource "azurerm_route" "pub_route1" {
  name                = "pub_route1"
  resource_group_name = azurerm_resource_group.bb_rg.name
  route_table_name    = azurerm_route_table.pub_rt.name
  address_prefix      = var.vnetCIDR
  next_hop_type       = "vnetlocal"
}

resource "azurerm_route" "pub_route2" {
  name                = "pub_route_igw"
  resource_group_name = azurerm_resource_group.bb_rg.name
  route_table_name    = azurerm_route_table.pub_rt.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "pub_rt_association" {
  subnet_id      = azurerm_subnet.public.id
  route_table_id = azurerm_route_table.pub_rt.id
}


resource "azurerm_public_ip" "nat_pub_ip" {
  name                = "nat-gateway-publicIP"
  resource_group_name = azurerm_resource_group.bb_rg.name
  location            = azurerm_resource_group.bb_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_public_ip_prefix" "nat_pub_ip_prefix" {
  name                = "nat-gateway-publicIPPrefix"
  resource_group_name = azurerm_resource_group.bb_rg.name
  location            = azurerm_resource_group.bb_rg.location
  prefix_length       = 30
  zones               = ["1"]
}

resource "azurerm_nat_gateway" "bb_natgw" {
  name                    = "nat-Gateway"
  resource_group_name     = azurerm_resource_group.bb_rg.name
  location                = azurerm_resource_group.bb_rg.location
  public_ip_address_ids   = [azurerm_public_ip.nat_pub_ip.id]
  public_ip_prefix_ids    = [azurerm_public_ip_prefix.nat_pub_ip_prefix.id]
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
}

resource "azurerm_subnet_nat_gateway_association" "natgw_association_bb" {
  subnet_id      = azurerm_subnet.bb.id
  nat_gateway_id = azurerm_nat_gateway.bb_natgw.id
}

resource "azurerm_subnet_nat_gateway_association" "natgw_association_es" {
  subnet_id      = azurerm_subnet.es.id
  nat_gateway_id = azurerm_nat_gateway.bb_natgw.id
}

resource "azurerm_subnet_nat_gateway_association" "natgw_association_appgw" {
  subnet_id      = azurerm_subnet.appgw.id
  nat_gateway_id = azurerm_nat_gateway.bb_natgw.id
}


resource "azurerm_network_security_group" "bb-nsg-public" {
  name                = "bb-nsg-public"
  resource_group_name = azurerm_resource_group.bb_rg.name
  location            = azurerm_resource_group.bb_rg.location
}


resource "azurerm_network_security_rule" "allow" {
  name                        = "allow"
  description                 = "Allows HTTP/S, SSH and Git traffic only from the Internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "80", "443", "7999"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-public.name
}

resource "azurerm_network_security_group" "bb-nsg-appgw" {
  name                = "bb-nsg-appgw"
  resource_group_name = azurerm_resource_group.bb_rg.name
  location            = azurerm_resource_group.bb_rg.location
}

resource "azurerm_network_security_rule" "allowHTTP" {
  name                        = "allowHTTP"
  description                 = "Allows HTTP/S traffic only from the Internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = var.appgwNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-appgw.name
}

resource "azurerm_network_security_rule" "allowAppGwProbes" {
  name                        = "allowAppGwProbes"
  description                 = "Allow Health Probe traffic"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["65503-65534"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-appgw.name
}


resource "azurerm_network_security_group" "bb-nsg-bb" {
  name                = "bb-nsg-bb"
  resource_group_name = azurerm_resource_group.bb_rg.name
  location            = azurerm_resource_group.bb_rg.location
}


resource "azurerm_network_security_rule" "allowAppGateway" {
  name                        = "allowAppGateway"
  description                 = "Allows incoming HTTP traffic from App Gateway subnet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["${var.bbsHttpPort}"]
  source_address_prefix       = var.appgwNetCIDR
  destination_address_prefix  = var.bbsNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-bb.name
}

resource "azurerm_network_security_rule" "allowGitSSH" {
  name                        = "allowGitSSH"
  description                 = "Allows incoming Git traffic from load balancer"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["7999"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = var.bbsNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-bb.name
}

resource "azurerm_network_security_rule" "allowSSH" {
  name                        = "allowSSH"
  description                 = "Allows incoming SSH traffic from public subnet"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22"]
  source_address_prefix       = var.publicNetCIDR
  destination_address_prefix  = var.bbsNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-bb.name
}

resource "azurerm_network_security_rule" "allowNFS" {
  name              = "allowNFS"
  description       = "Allows NFS traffic inside the subnet"
  priority          = 200
  direction         = "Inbound"
  access            = "Allow"
  protocol          = "*"
  source_port_range = "*"
  destination_port_ranges = [
    "111",
    "2049",
    "1110",
    "4045",
    "32764-32769"
  ]
  source_address_prefix       = var.bbsNetCIDR
  destination_address_prefix  = var.bbsNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-bb.name
}

resource "azurerm_network_security_rule" "allowHazelcast" {
  name                        = "allowHazelcast"
  description                 = "Allows Hazelcast traffic inside the subnet"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["${var.bbsHazelcastPort}"]
  source_address_prefix       = var.bbsNetCIDR
  destination_address_prefix  = var.bbsNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-bb.name
}

resource "azurerm_network_security_rule" "allowLoadBalancingHealthProbe" {
  name                        = "allowLoadBalancingHealthProbe"
  description                 = "Allow health probe traffic"
  priority                    = 202
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["7990"]
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = var.bbsNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-bb.name
}

resource "azurerm_network_security_group" "bb-nsg-es" {
  name                = "bb-nsg-es"
  resource_group_name = azurerm_resource_group.bb_rg.name
  location            = azurerm_resource_group.bb_rg.location
}


resource "azurerm_network_security_rule" "allowBBS" {
  name                        = "allowBBS"
  description                 = "Allows incoming traffic from BBS nodes"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["9200", "9300"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = var.esNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-es.name
}

resource "azurerm_network_security_rule" "allowSSH_es" {
  name                        = "allowSSH_es"
  description                 = "Allows incoming SSH traffic from jumpbox to ES data nodes"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = var.esNetCIDR
  resource_group_name         = azurerm_resource_group.bb_rg.name
  network_security_group_name = azurerm_network_security_group.bb-nsg-es.name
}