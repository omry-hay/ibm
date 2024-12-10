terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
      version = ">= 1.12.0"
    }
  }
}

# Configure the IBM Provider
provider "ibm" {
  region = "us-south"
}

locals {
  bucket_name = "a-standard-bucket-at-ams-env0-test"
}

data "ibm_iam_access_group" "public_access_group" {
  access_group_name = "Public Access"
}

resource "ibm_resource_instance" "cos_instance" {
  name              = "cos-instance"
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
}

resource "ibm_cos_bucket" "standard-ams03" {
  bucket_name          = local.bucket_name
  resource_instance_id = ibm_resource_instance.cos_instance.id
  single_site_location = "ams03"
  storage_class        = "standard"
}

resource "ibm_iam_access_group_policy" "policy" { 
  depends_on = [ibm_cos_bucket.standard-ams03] 
  access_group_id = data.ibm_iam_access_group.public_access_group.groups[0].id 
  roles = ["Object Reader"] 

  resources { 
    service = "cloud-object-storage" 
    resource_type = "bucket" 
    resource_instance_id = "COS instance guid"  # eg : 94xxxxxx-3xxx-4xxx-8xxx-7xxxxxxxxx7
    resource = ibm_cos_bucket.standard-ams03.bucket_name
  } 
} 

resource ibm_cos_bucket_website_configuration "website" {
  depends_on = [ibm_cos_bucket.standard-ams03, ibm_iam_access_group_policy.policy] 
  bucket_crn = ibm_cos_bucket.standard-ams03.crn
  bucket_location = ibm_cos_bucket.standard-ams03.single_site_location
  website_configuration {
    error_document{
      key = "error.html"
    }
    index_document{
      suffix = "index.html"
    }
  }
}

resource "ibm_cos_bucket_object" "file" {
  depends_on      = [ibm_cos_bucket.standard-ams03, ibm_cos_bucket_website_configuration.website] 
  bucket_crn      = ibm_cos_bucket.standard-ams03.crn
  bucket_location = ibm_cos_bucket.standard-ams03.single_site_location
  content_file    = "${path.module}/index.html"
  key             = "index.html"
  etag            = filemd5("${path.module}/index.html")
}

data "ibm_cos_bucket" "bucket_data" {
  depends_on           = [ibm_cos_bucket_object.file] 
  bucket_name          = local.bucket_name
  resource_instance_id = ibm_resource_instance.cos_instance.id
  bucket_region        = ibm_cos_bucket.standard-ams03.region_location
  bucket_type          = ibm_cos_bucket.standard-ams03.single_site_location
}

output "website-link" {
  value = data.ibm_cos_bucket.bucket_data.website_endpoint
}
