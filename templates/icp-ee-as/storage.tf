# TODO: Create storage account for azure-disk type:shared
# Use the storage account to pupulate this:
# kind: StorageClass
# apiVersion: storage.k8s.io/v1
# metadata:
#   name: slow
# provisioner: kubernetes.io/azure-disk
# parameters:
#   skuName: Standard_LRS
#   location: eastus
#   storageAccount: azure_storage_account_name

#########
## Storage account for ICP components
#########
resource "azurerm_storage_account" "infrastructure" {
  name                     = "infrastructure${random_id.clusterid.hex}"
  resource_group_name      = "${local.rg_name}"
  location                 = "${var.location}"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_replication_type}"

  tags {
    environment = "icp"
  }
}

resource "azurerm_storage_share" "icpregistry" {
  name = "icpregistry"

  resource_group_name  = "${local.rg_name}"
  storage_account_name = "${azurerm_storage_account.infrastructure.name}"
  quota = 300
}

# blob storage account for uploading images
resource "azurerm_storage_account" "blobstorage" {
  name                     = "icp4d${random_id.clusterid.hex}"
  resource_group_name      = "${local.rg_name}"
  location                 = "${var.location}"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_replication_type}"
  account_kind             = "BlobStorage"
}

resource "azurerm_storage_container" "images" {
  name                  = "icpimages"
  resource_group_name   = "${local.rg_name}"
  storage_account_name  = "${azurerm_storage_account.blobstorage.name}"
  container_access_type = "blob"
}

# create the resource only if not yet pre-uploaded
resource "azurerm_storage_blob" "icpimage" {
  count = "${var.image_location != "default" && substr(var.image_location,0,5) != "https" ? 1 : 0}"
  name = "${basename(var.image_location)}"
  source = "${var.image_location}"
  type="block"
  resource_group_name    = "${local.rg_name}"
  storage_account_name   = "${azurerm_storage_account.blobstorage.name}"
  storage_container_name = "${azurerm_storage_container.images.name}"
  parallelism=8
  attempts=3
}

resource "azurerm_storage_blob" "icpdocker" {
  #icp docker should work for ubuntu too, for now use for rhel only
  count = "${var.os_image == "rhel" && var.image_location_docker != "default" && substr(var.image_location_docker,0,5) != "https" ? 1 : 0}"
  name = "${basename(var.image_location_docker)}"
  source = "${var.image_location_docker}"
  type="block"
  resource_group_name    = "${local.rg_name}"
  storage_account_name   = "${azurerm_storage_account.blobstorage.name}"
  storage_container_name = "${azurerm_storage_container.images.name}"
  parallelism=8
  attempts=3
}

# create the resource only if not yet pre-uploaded, wait until icp upload is done
resource "azurerm_storage_blob" "icp4dimage" {
  depends_on = ["azurerm_storage_blob.icpimage"]
  count = "${var.image_location_icp4d != "default" && substr(var.image_location_icp4d,0,5) != "https" ? 1 : 0}"
  name = "${basename(var.image_location_icp4d)}"
  source = "${var.image_location_icp4d}"
  type="block"
  resource_group_name    = "${local.rg_name}"
  storage_account_name   = "${azurerm_storage_account.blobstorage.name}"
  storage_container_name = "${azurerm_storage_container.images.name}"
  parallelism=8
  attempts=3
}

